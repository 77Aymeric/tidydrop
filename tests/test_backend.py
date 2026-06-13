from __future__ import annotations

from pathlib import Path

import pytest

from backend.classifier import discover_categories, is_generic_category_name, normalize_result
from backend.models import (
    Category,
    ClassificationResult,
    ClassificationSettings,
    FileItem,
    PlanRequest,
    PlanSettings,
    ScanRequest,
)
from backend.operations import apply_plan
from backend.ollama_client import (
    CATEGORY_DISCOVERY_SCHEMA,
    CLASSIFICATION_SCHEMA,
    _load_image_b64,
    build_category_discovery_prompt,
)
from backend.planner import create_plan
from backend.scanner import detect_kind, scan_folder
from backend.undo import apply_undo, preview_undo


def item(path: Path) -> FileItem:
    return FileItem(
        path=str(path),
        name=path.name,
        extension=path.suffix,
        size=path.stat().st_size,
        last_modified="2026-06-06T00:00:00+02:00",
        file_kind=detect_kind(path),
    )


def test_detect_kind_and_scan_defaults(tmp_path: Path) -> None:
    (tmp_path / "note.txt").write_text("hello", encoding="utf-8")
    (tmp_path / "script.py").write_text("print('x')", encoding="utf-8")
    ignored = tmp_path / "node_modules"
    ignored.mkdir()
    (ignored / "package.json").write_text("{}", encoding="utf-8")

    response = scan_folder(ScanRequest(folder_path=str(tmp_path)))

    assert detect_kind(tmp_path / "note.txt") == "text"
    assert detect_kind(tmp_path / "script.py") == "code"
    assert response.summary.total_files == 2
    assert {file.name for file in response.files} == {"note.txt", "script.py"}


def test_scan_excludes_output_folder(tmp_path: Path) -> None:
    (tmp_path / "source.txt").write_text("source", encoding="utf-8")
    output = tmp_path / "Custom Sorted"
    output.mkdir()
    (output / "copy.txt").write_text("copy", encoding="utf-8")

    response = scan_folder(
        ScanRequest(
            folder_path=str(tmp_path),
            excluded_paths=[str(output)],
        )
    )

    assert [file.name for file in response.files] == ["source.txt"]


def test_invalid_or_low_confidence_classification_falls_back(tmp_path: Path) -> None:
    file_path = tmp_path / "a.txt"
    file_path.write_text("ambiguous", encoding="utf-8")
    file = item(file_path)

    result = normalize_result(
        file,
        {"category_id": "invented", "confidence": 0.99, "reason": "bad category"},
        {"docs", "review"},
        "review",
        0.75,
    )
    low = normalize_result(
        file,
        {"category_id": "docs", "confidence": 0.2, "reason": "weak"},
        {"docs", "review"},
        "review",
        0.75,
    )

    assert result.suggested_category_id == "review"
    assert low.suggested_category_id == "review"
    assert low.needs_review is True


def test_images_are_loaded_lazily_for_vision(tmp_path: Path) -> None:
    image_path = tmp_path / "sample.png"
    image_path.write_bytes(b"small-image-payload")

    response = scan_folder(ScanRequest(folder_path=str(tmp_path)))
    image = response.files[0]

    assert image.file_kind == "image"
    assert image.image_b64 is None
    assert _load_image_b64(image) == "c21hbGwtaW1hZ2UtcGF5bG9hZA=="


def test_ollama_schemas_require_structured_results() -> None:
    assert CLASSIFICATION_SCHEMA["required"] == [
        "category_id",
        "confidence",
        "reason",
        "suggested_filename",
        "needs_review",
    ]
    assert CATEGORY_DISCOVERY_SCHEMA["required"] == ["categories"]


def test_extension_only_confidence_is_calibrated(tmp_path: Path) -> None:
    file_path = tmp_path / "animation.gif"
    file_path.write_bytes(b"GIF89a")
    file = item(file_path)

    result = normalize_result(
        file,
        {
            "category_id": "media",
            "confidence": 1,
            "reason": "The file extension .gif falls under Media.",
            "suggested_filename": None,
            "needs_review": False,
        },
        {"media", "review"},
        "review",
        0,
    )

    assert result.confidence == 0.35
    assert result.needs_review is True


def test_confidence_never_reaches_one(tmp_path: Path) -> None:
    file_path = tmp_path / "alpha.md"
    file_path.write_text("Project Alpha migration plan", encoding="utf-8")
    file = item(file_path)

    result = normalize_result(
        file,
        {
            "category_id": "alpha",
            "confidence": 1,
            "reason": "Content explicitly mentions Project Alpha migration.",
            "suggested_filename": "project-alpha-migration-plan.md",
            "needs_review": False,
        },
        {"alpha", "review"},
        "review",
        0,
    )

    assert result.confidence == 0.98


def test_generic_filename_uses_document_title(tmp_path: Path) -> None:
    file_path = tmp_path / "doc.md"
    file_path.write_text("# TidyDrop Synthetic Project Brief\n\nDetails", encoding="utf-8")
    file = item(file_path)
    file.content_preview = "# TidyDrop Synthetic Project Brief\n\nDetails"

    result = normalize_result(
        file,
        {
            "category_id": "workspace",
            "confidence": 0.92,
            "reason": "Content explicitly describes the TidyDrop workspace.",
            "suggested_filename": "doc.md",
            "needs_review": False,
        },
        {"workspace", "review"},
        "review",
        0,
    )

    assert result.suggested_filename == "tidydrop-synthetic-project-brief.md"
    assert result.should_rename is True


def test_suggested_filename_preserves_original_extension(tmp_path: Path) -> None:
    file_path = tmp_path / "photo.jpg"
    file_path.write_bytes(b"image")
    file = item(file_path)

    result = normalize_result(
        file,
        {
            "category_id": "assets",
            "confidence": 0.9,
            "reason": "Visible content matches the Project Alpha assets.",
            "suggested_filename": "project-alpha-logo.png",
            "needs_review": False,
        },
        {"assets", "review"},
        "review",
        0,
    )

    assert result.suggested_filename == "project-alpha-logo.jpg"


def test_generic_ai_categories_are_rejected() -> None:
    assert is_generic_category_name("Documents")
    assert is_generic_category_name("Media")
    assert not is_generic_category_name("Project Alpha")


def test_category_discovery_prompt_is_project_first(tmp_path: Path) -> None:
    file_path = tmp_path / "client-alpha-report.md"
    file_path.write_text("Client Alpha migration project, March 2026", encoding="utf-8")
    file = item(file_path)
    prompt = build_category_discovery_prompt(
        [file],
        [Category(id="documents", name="Documents")],
        ClassificationSettings(allow_ai_categories=True, text_model="test-model"),
    )

    assert "shared project, client, organization" in prompt
    assert "Do not create categories based only on extensions" in prompt


@pytest.mark.asyncio
async def test_ai_category_discovery_adds_categories_before_classification(tmp_path: Path) -> None:
    class FakeClient:
        async def discover_categories(self, files, categories, settings):
            return {
                "categories": [
                    {
                        "id": "tax-papers",
                        "name": "Tax Papers",
                        "description": "Tax returns and fiscal documents",
                        "rules": "Use for tax-related PDFs and forms.",
                    },
                    {
                        "id": "docs",
                        "name": "Documents",
                        "description": "Duplicate should be ignored",
                        "rules": "",
                    },
                ]
            }

    file_path = tmp_path / "tax_return.pdf"
    file_path.write_text("tax return 2026", encoding="utf-8")
    categories = [Category(id="docs", name="Documents")]

    final_categories, added = await discover_categories(
        [item(file_path)],
        categories,
        ClassificationSettings(allow_ai_categories=True, text_model="test-model"),
        client=FakeClient(),
    )

    assert [category.id for category in added] == ["tax-papers"]
    assert any(category.id == "review" for category in final_categories)
    assert [category.id for category in final_categories].count("docs") == 1


def test_plan_apply_history_and_move_undo(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    app_dir = tmp_path / "home"
    runs_dir = app_dir / "runs"
    undone_dir = app_dir / "undone"
    monkeypatch.setattr("backend.config.RUNS_DIR", runs_dir)
    monkeypatch.setattr("backend.config.UNDONE_DIR", undone_dir)
    monkeypatch.setattr("backend.history.RUNS_DIR", runs_dir)
    monkeypatch.setattr("backend.undo.UNDONE_DIR", undone_dir)

    source = tmp_path / "source"
    output = tmp_path / "sorted"
    source.mkdir()
    original = source / "report.txt"
    original.write_text("school report", encoding="utf-8")
    file = item(original)
    categories = [Category(id="docs", name="Documents"), Category(id="review", name="To Review")]
    results = [
        ClassificationResult(
            file_id=file.id,
            original_path=file.path,
            suggested_category_id="docs",
            confidence=0.94,
            reason="text document",
        )
    ]
    plan = create_plan(
        PlanRequest(
            source_folder=str(source),
            files=[file],
            categories=categories,
            results=results,
            settings=PlanSettings(mode="move", output_folder=str(output)),
        )
    )

    applied = apply_plan(plan)
    assert applied.operations[0].status == "done"
    assert not original.exists()
    assert Path(applied.operations[0].actual_path or "").exists()

    preview = preview_undo(applied.run_id)
    assert preview.actions[0].status == "pending"
    undone = apply_undo(applied.run_id)
    assert undone.actions[0].status == "done"
    assert original.exists()


def test_plan_applies_reviewed_name_and_preserves_extension(tmp_path: Path) -> None:
    source = tmp_path / "source"
    output = tmp_path / "sorted"
    source.mkdir()
    original = source / "draft.md"
    original.write_text("Project Alpha launch notes", encoding="utf-8")
    file = item(original)

    plan = create_plan(
        PlanRequest(
            source_folder=str(source),
            files=[file],
            categories=[Category(id="alpha", name="Project Alpha")],
            results=[
                ClassificationResult(
                    file_id=file.id,
                    original_path=file.path,
                    suggested_category_id="alpha",
                    confidence=0.95,
                    reason="Project Alpha content",
                    suggested_filename="launch-notes",
                )
            ],
            settings=PlanSettings(
                mode="copy",
                output_folder=str(output),
                suggest_renaming=True,
                apply_renaming=True,
            ),
        )
    )

    assert Path(plan.operations[0].target_path).name == "launch-notes.md"
    assert Path(plan.operations[0].target_path).parent.name == "Project Alpha"


def test_copy_undo_moves_copy_to_holding_folder(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    app_dir = tmp_path / "home"
    runs_dir = app_dir / "runs"
    undone_dir = app_dir / "undone"
    monkeypatch.setattr("backend.config.RUNS_DIR", runs_dir)
    monkeypatch.setattr("backend.config.UNDONE_DIR", undone_dir)
    monkeypatch.setattr("backend.history.RUNS_DIR", runs_dir)
    monkeypatch.setattr("backend.undo.UNDONE_DIR", undone_dir)

    source = tmp_path / "source"
    output = tmp_path / "sorted"
    source.mkdir()
    original = source / "report.txt"
    original.write_text("school report", encoding="utf-8")
    file = item(original)
    categories = [Category(id="docs", name="Documents")]
    results = [
        ClassificationResult(
            file_id=file.id,
            original_path=file.path,
            suggested_category_id="docs",
            confidence=0.94,
            reason="text document",
        )
    ]
    plan = create_plan(
        PlanRequest(
            source_folder=str(source),
            files=[file],
            categories=categories,
            results=results,
            settings=PlanSettings(mode="copy", output_folder=str(output)),
        )
    )
    applied = apply_plan(plan)
    copied = Path(applied.operations[0].actual_path or "")

    undone = apply_undo(applied.run_id)

    assert original.exists()
    assert not copied.exists()
    assert undone.actions[0].status == "done"
    assert (undone_dir / applied.run_id / "report.txt").exists()
