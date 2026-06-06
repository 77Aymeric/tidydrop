from __future__ import annotations

from pathlib import Path

from backend.config import MAX_PREVIEW_CHARS


def extract_docx(path: Path) -> tuple[str, str, str, str | None]:
    try:
        from docx import Document

        document = Document(str(path))
        paragraphs = [p.text.strip() for p in document.paragraphs if p.text.strip()]
        preview = "\n".join(paragraphs[:40])[:MAX_PREVIEW_CHARS]
        return preview, f"DOCX with {len(paragraphs)} non-empty sampled paragraphs.", "partial", None
    except Exception as exc:
        return "", f"DOCX extraction unavailable: {exc}", "metadata_only", None
