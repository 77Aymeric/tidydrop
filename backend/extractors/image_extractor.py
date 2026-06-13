from __future__ import annotations

from pathlib import Path


def extract_image(path: Path) -> tuple[str, str, str, str | None]:
    stat = path.stat()
    summary = f"Image file; extension: {path.suffix.lower()}; size: {stat.st_size} bytes."
    return "", summary, "partial", None
