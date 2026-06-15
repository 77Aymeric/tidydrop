from __future__ import annotations

import re
import unicodedata
from pathlib import Path
from uuid import uuid4

from pydantic import BaseModel

from backend.config import PLANS_DIR, ensure_app_dirs
from backend.models import Category, OperationEntry, OperationPlan, PlanConflict, PlanRequest, utc_now_id
from backend.security import require_path_within, validate_identifier
from backend.state import load_scan

CONTROL_OR_FORMAT_RE = re.compile(r"[\x00-\x1f\x7f-\x9f\u200b-\u200f\u202a-\u202e\u2060-\u206f]")
FORBIDDEN_RE = re.compile(r"[/:\\]+")


class StoredPlan(BaseModel):
    plan: OperationPlan
    categories: list[Category]
    apply_renaming: bool


def create_plan(request: PlanRequest) -> OperationPlan:
    session = load_scan(request.scan_id)
    run_id, created_at = utc_now_id()
    plan_id = str(uuid4())
    categories_by_id = {category.id: category for category in request.categories}
    if len(categories_by_id) != len(request.categories):
        raise ValueError("Category identifiers must be unique.")
    output_root = Path(request.settings.output_folder).expanduser().resolve(strict=False)
    results_by_file = {result.file_id: result for result in request.results}
    reserved: set[Path] = set()
    operations: list[OperationEntry] = []

    for file in session.files():
        result = results_by_file.get(file.id)
        if result is None:
            continue
        category = categories_by_id.get(result.suggested_category_id)
        if category is None:
            continue
        source = require_path_within(file.path, session.root, "Source file")
        if not source.is_file():
            continue
        filename = file.name
        if request.settings.apply_renaming and result.suggested_filename:
            filename = sanitize_filename(result.suggested_filename, fallback=file.name)
            if file.extension:
                filename = f"{Path(filename).stem}{file.extension}"
        target_dir = output_root / sanitize_filename(category.name, fallback=category.id)
        target_path, conflict = reserve_preview_path(target_dir / filename, reserved)
        operations.append(
            OperationEntry(
                type=request.settings.mode,
                original_path=str(source),
                target_path=str(target_path),
                category_id=category.id,
                suggested_filename=result.suggested_filename,
                confidence=result.confidence,
                reason=result.reason,
                conflict=conflict,
            )
        )

    plan = OperationPlan(
        plan_id=plan_id,
        run_id=run_id,
        created_at=created_at,
        source_folder=str(session.root),
        output_folder=str(output_root),
        mode=request.settings.mode,
        operations=operations,
    )
    save_pending_plan(
        StoredPlan(
            plan=plan,
            categories=request.categories,
            apply_renaming=request.settings.apply_renaming,
        )
    )
    return plan


def save_pending_plan(record: StoredPlan) -> None:
    ensure_app_dirs()
    validate_identifier(record.plan.plan_id, "plan identifier")
    path = PLANS_DIR / f"{record.plan.plan_id}.json"
    _atomic_write(path, record.model_dump_json(indent=2))


def load_pending_plan(plan_id: str) -> StoredPlan:
    ensure_app_dirs()
    validate_identifier(plan_id, "plan identifier")
    path = PLANS_DIR / f"{plan_id}.json"
    if not path.exists():
        raise FileNotFoundError("Plan was not found or has expired.")
    return StoredPlan.model_validate_json(path.read_text(encoding="utf-8"))


def delete_pending_plan(plan_id: str) -> None:
    validate_identifier(plan_id, "plan identifier")
    (PLANS_DIR / f"{plan_id}.json").unlink(missing_ok=True)


def sanitize_filename(name: str, fallback: str) -> str:
    normalized = unicodedata.normalize("NFC", name)
    normalized = CONTROL_OR_FORMAT_RE.sub("", normalized)
    normalized = FORBIDDEN_RE.sub("-", normalized)
    normalized = " ".join(normalized.split())
    cleaned = normalized.strip(" .")
    if cleaned in {"", ".", ".."}:
        cleaned = unicodedata.normalize("NFC", fallback)
        cleaned = CONTROL_OR_FORMAT_RE.sub("", cleaned)
        cleaned = FORBIDDEN_RE.sub("-", cleaned).strip(" .")
    return cleaned[:240] or "Untitled"


def reserve_preview_path(path: Path, reserved: set[Path]) -> tuple[Path, PlanConflict | None]:
    candidate = path
    index = 0
    while candidate.exists() or candidate in reserved:
        index += 1
        candidate = path.with_name(f"{path.stem} ({index}){path.suffix}")
        if index >= 10_000:
            raise FileExistsError(f"Could not find available target path for {path}")
    reserved.add(candidate)
    if candidate == path:
        return candidate, None
    reason = "target_exists" if path.exists() else "duplicate_in_plan"
    return candidate, PlanConflict(type=reason, message=f"Using conflict-safe name {candidate.name}.")


def alternate_path(path: Path) -> Path:
    return reserve_preview_path(path, set())[0]


def _atomic_write(path: Path, contents: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{uuid4().hex}.tmp")
    temporary.write_text(contents, encoding="utf-8")
    temporary.chmod(0o600)
    temporary.replace(path)
