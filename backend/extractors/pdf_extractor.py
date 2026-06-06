from __future__ import annotations

from pathlib import Path

from backend.config import MAX_PREVIEW_CHARS


def extract_pdf(path: Path) -> tuple[str, str, str, str | None]:
    try:
        import fitz

        parts: list[str] = []
        with fitz.open(path) as doc:
            for page in doc[:3]:
                parts.append(page.get_text())
            preview = "\n".join(parts).strip()[:MAX_PREVIEW_CHARS]
            summary = f"PDF with {doc.page_count} pages; sampled first {min(3, doc.page_count)} pages."
        return preview or "No extractable text", summary, "partial", None
    except Exception as exc:
        return "", f"PDF text extraction unavailable: {exc}", "metadata_only", None
