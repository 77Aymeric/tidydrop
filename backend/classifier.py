from __future__ import annotations

import re
from pathlib import Path

from backend.models import Category, ClassificationResult, ClassificationSettings, FileItem
from backend.ollama_client import OllamaClient


async def classify_files(
    files: list[FileItem],
    categories: list[Category],
    settings: ClassificationSettings,
    client: OllamaClient | None = None,
) -> list[ClassificationResult]:
    client = client or OllamaClient()
    valid_category_ids = {category.id for category in categories}
    fallback_id = ensure_fallback(categories, settings.fallback_category_id)
    results: list[ClassificationResult] = []
    for file in files:
        try:
            raw = (
                await client.classify_image(file, categories, settings)
                if file.file_kind == "image" and (settings.vision_model or settings.model)
                else await client.classify_text(file, categories, settings)
            )
            results.append(normalize_result(file, raw, valid_category_ids, fallback_id, settings.confidence_threshold))
        except Exception as exc:
            results.append(
                ClassificationResult(
                    file_id=file.id,
                    original_path=file.path,
                    suggested_category_id=fallback_id,
                    confidence=0,
                    reason=f"Needs review: {exc}",
                    needs_review=True,
                )
            )
    return results


async def discover_categories(
    files: list[FileItem],
    categories: list[Category],
    settings: ClassificationSettings,
    client: OllamaClient | None = None,
) -> tuple[list[Category], list[Category]]:
    if not settings.allow_ai_categories:
        return ensure_review_category(categories), []
    client = client or OllamaClient()
    existing = ensure_review_category(categories)
    raw = await client.discover_categories(files, existing, settings)

    valid_existing_ids = {category.id for category in existing}
    valid_existing_names = {category.name.casefold() for category in existing}
    added: list[Category] = []
    for raw_category in raw.get("categories", []):
        if not isinstance(raw_category, dict):
            continue
        name = str(raw_category.get("name") or "").strip()
        if not name or name.casefold() in valid_existing_names:
            continue
        if is_generic_category_name(name):
            continue
        category_id = slugify(str(raw_category.get("id") or name))
        if not category_id or category_id in valid_existing_ids or any(category.id == category_id for category in added):
            category_id = unique_id(slugify(name), valid_existing_ids | {category.id for category in added})
        if category_id == "review" or name.casefold() in {"to review", "à vérifier", "a verifier"}:
            continue
        added.append(
            Category(
                id=category_id,
                name=name[:60],
                description=f"Files related to {name} based on shared content, names, and dates."[:180],
                rules=str(
                    raw_category.get("signals")
                    or raw_category.get("rules")
                    or raw_category.get("description")
                    or ""
                )[:240],
            )
        )
        if len(added) >= settings.max_ai_categories:
            break
    return existing + added, added


def is_generic_category_name(name: str) -> bool:
    normalized = name.casefold().strip()
    generic = {
        "document",
        "documents",
        "code",
        "image",
        "images",
        "media",
        "pdf",
        "pdfs",
        "spreadsheet",
        "spreadsheets",
        "archive",
        "archives",
        "audio",
        "video",
        "other",
        "misc",
        "miscellaneous",
    }
    return normalized in generic


def ensure_fallback(categories: list[Category], fallback_id: str) -> str:
    if any(category.id == fallback_id for category in categories):
        return fallback_id
    review = next((category.id for category in categories if category.name.lower() in {"to review", "à vérifier", "a verifier"}), None)
    return review or categories[-1].id


def ensure_review_category(categories: list[Category]) -> list[Category]:
    if any(category.id == "review" or category.name.casefold() == "to review" for category in categories):
        return categories
    return categories + [
        Category(
            id="review",
            name="To Review",
            description="Files TidyDrop is unsure about.",
            rules="Use this when confidence is low.",
        )
    ]


def slugify(value: str) -> str:
    value = value.lower()
    value = re.sub(r"[^a-z0-9]+", "-", value)
    return value.strip("-")[:48]


def unique_id(base: str, existing_ids: set[str]) -> str:
    base = base or "ai-folder"
    if base not in existing_ids:
        return base
    for index in range(2, 100):
        candidate = f"{base}-{index}"
        if candidate not in existing_ids:
            return candidate
    return f"{base}-new"


def normalize_result(
    file: FileItem,
    raw: dict,
    valid_category_ids: set[str],
    fallback_id: str,
    threshold: float,
) -> ClassificationResult:
    category_id = str(raw.get("category_id") or raw.get("suggested_category_id") or fallback_id)
    confidence = _float(raw.get("confidence"), 0)
    needs_review = bool(raw.get("needs_review", False))
    reason = str(raw.get("reason") or "No reason returned.")[:300]
    if _reason_relies_on_file_type(reason):
        confidence = min(confidence, 0.35)
        needs_review = True
    if category_id not in valid_category_ids or confidence < threshold:
        category_id = fallback_id
        needs_review = True
    suggested_filename = raw.get("suggested_filename")
    if suggested_filename is not None:
        suggested_filename = str(suggested_filename).strip() or None
    if (
        not suggested_filename
        or suggested_filename.casefold() == file.name.casefold()
    ) and _filename_needs_improvement(file.name):
        suggested_filename = _semantic_filename_from_content(file)
    suggested_filename = _preserve_original_extension(suggested_filename, file.extension)
    return ClassificationResult(
        file_id=file.id,
        original_path=file.path,
        suggested_category_id=category_id,
        confidence=max(0, min(0.98, confidence)),
        reason=reason,
        suggested_filename=suggested_filename,
        should_rename=bool(suggested_filename and suggested_filename != file.name),
        needs_review=needs_review,
    )


def _float(value: object, default: float) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _reason_relies_on_file_type(reason: str) -> bool:
    lowered = reason.casefold()
    file_type_signals = (
        "file extension",
        "extension .",
        "file type",
        "falls under",
        "is a markdown",
        "is a csv",
        "is an html",
        "is a javascript",
        "is an animated gif",
    )
    semantic_signals = (
        "project",
        "client",
        "subject",
        "content",
        "contains",
        "mentions",
        "visible",
        "contract",
        "invoice",
        "meeting",
        "migration",
        "administrative",
    )
    return any(signal in lowered for signal in file_type_signals) and not any(
        signal in lowered for signal in semantic_signals
    )


def _filename_needs_improvement(filename: str) -> bool:
    stem = re.sub(r"\.[^.]+$", "", filename.casefold())
    generic_tokens = (
        "copy",
        "old",
        "final",
        "draft",
        "tmp",
        "temp",
        "scan",
        "export",
        "doc",
        "item",
        "data",
        "notes",
    )
    return any(token in stem for token in generic_tokens) or bool(re.fullmatch(r"[\d_-]+", stem))


def _semantic_filename_from_content(file: FileItem) -> str | None:
    for line in file.content_preview.splitlines()[:12]:
        title = re.sub(r"^[#>*\-\s]+", "", line).strip()
        if not 4 <= len(title) <= 100:
            continue
        words = re.findall(r"[A-Za-z0-9À-ÿ]+", title)
        if len(words) < 2:
            continue
        stem = "-".join(words[:10]).casefold()
        return f"{stem}{file.extension}"
    return None


def _preserve_original_extension(filename: str | None, extension: str) -> str | None:
    if not filename or not extension:
        return filename
    path = Path(filename)
    return f"{path.stem}{extension}"
