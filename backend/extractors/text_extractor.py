from __future__ import annotations

from pathlib import Path

from backend.config import MAX_PREVIEW_CHARS


def extract_text(path: Path) -> tuple[str, str, str, str | None]:
    data = path.read_bytes()[: MAX_PREVIEW_CHARS * 4]
    text = data.decode("utf-8", errors="replace")[:MAX_PREVIEW_CHARS]
    lines = text.splitlines()
    summary = f"Text preview with {len(lines)} sampled lines."
    return text, summary, "partial", None
