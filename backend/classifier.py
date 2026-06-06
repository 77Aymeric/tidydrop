from __future__ import annotations

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
                if file.file_kind == "image" and file.image_b64 and (settings.vision_model or settings.model)
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


def ensure_fallback(categories: list[Category], fallback_id: str) -> str:
    if any(category.id == fallback_id for category in categories):
        return fallback_id
    review = next((category.id for category in categories if category.name.lower() in {"to review", "à vérifier", "a verifier"}), None)
    return review or categories[-1].id


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
    if category_id not in valid_category_ids or confidence < threshold:
        category_id = fallback_id
        needs_review = True
    suggested_filename = raw.get("suggested_filename")
    if suggested_filename is not None:
        suggested_filename = str(suggested_filename).strip() or None
    return ClassificationResult(
        file_id=file.id,
        original_path=file.path,
        suggested_category_id=category_id,
        confidence=max(0, min(1, confidence)),
        reason=str(raw.get("reason") or "No reason returned.")[:300],
        suggested_filename=suggested_filename,
        should_rename=bool(suggested_filename and suggested_filename != file.name),
        needs_review=needs_review,
    )


def _float(value: object, default: float) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default
