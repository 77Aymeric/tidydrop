from __future__ import annotations

import base64
from pathlib import Path

from backend.config import MAX_IMAGE_BYTES


def extract_image(path: Path) -> tuple[str, str, str, str | None]:
    stat = path.stat()
    image_b64 = None
    level = "metadata_only"
    if stat.st_size <= MAX_IMAGE_BYTES:
        try:
            image_b64 = base64.b64encode(path.read_bytes()).decode("ascii")
            level = "full"
        except Exception:
            image_b64 = None
    summary = f"Image file; extension: {path.suffix.lower()}; size: {stat.st_size} bytes."
    return "", summary, level, image_b64
