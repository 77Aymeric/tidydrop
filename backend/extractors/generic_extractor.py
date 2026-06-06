from __future__ import annotations

from pathlib import Path


def extract_generic(path: Path) -> tuple[str, str, str, str | None]:
    stat = path.stat()
    summary = f"Name: {path.name}; extension: {path.suffix or 'none'}; size: {stat.st_size} bytes"
    return "", summary, "metadata_only", None
