from __future__ import annotations

from pathlib import Path


def extract_media(path: Path) -> tuple[str, str, str, str | None]:
    stat = path.stat()
    summary = f"Media file; extension: {path.suffix.lower()}; size: {stat.st_size} bytes."
    return "", summary, "metadata_only", None
