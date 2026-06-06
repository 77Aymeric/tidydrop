from __future__ import annotations

from pathlib import Path
from zipfile import ZipFile, is_zipfile

from backend.config import MAX_PREVIEW_CHARS


def extract_archive(path: Path) -> tuple[str, str, str, str | None]:
    if path.suffix.lower() == ".zip" and is_zipfile(path):
        try:
            with ZipFile(path) as archive:
                names = archive.namelist()[:200]
            return "\n".join(names)[:MAX_PREVIEW_CHARS], f"ZIP archive with {len(names)} sampled entries.", "partial", None
        except Exception as exc:
            return "", f"ZIP listing unavailable: {exc}", "metadata_only", None
    return "", "Archive metadata only; no extraction performed.", "metadata_only", None
