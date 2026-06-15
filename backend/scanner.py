from __future__ import annotations

import mimetypes
import os
import json
import subprocess
import sys
from datetime import datetime
from pathlib import Path

from backend.extractors import (
    extract_archive,
    extract_docx,
    extract_generic,
    extract_image,
    extract_media,
    extract_pdf,
    extract_text,
    extract_xlsx,
)
from backend.models import FileItem, FileKind, ScanRequest, ScanResponse, ScanSummary

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".heic", ".avif", ".gif", ".bmp", ".tiff", ".tif"}
TEXT_EXTS = {".txt", ".md", ".csv", ".json", ".xml", ".yaml", ".yml", ".rtf"}
CODE_EXTS = {
    ".c",
    ".h",
    ".cpp",
    ".hpp",
    ".py",
    ".java",
    ".js",
    ".jsx",
    ".ts",
    ".tsx",
    ".html",
    ".css",
    ".sql",
    ".sh",
    ".swift",
    ".go",
    ".rs",
    ".php",
    ".rb",
}
ARCHIVE_EXTS = {".zip", ".rar", ".7z", ".tar", ".gz", ".tgz"}
AUDIO_EXTS = {".mp3", ".wav", ".m4a", ".flac", ".aac", ".ogg"}
VIDEO_EXTS = {".mp4", ".mov", ".avi", ".mkv", ".webm", ".m4v"}
ISOLATED_KINDS = {"pdf", "docx", "spreadsheet", "archive"}
EXTRACTION_TIMEOUT_SECONDS = 8


def detect_kind(path: Path) -> FileKind:
    suffix = path.suffix.lower()
    if suffix in IMAGE_EXTS:
        return "image"
    if suffix == ".pdf":
        return "pdf"
    if suffix == ".docx":
        return "docx"
    if suffix == ".xlsx":
        return "spreadsheet"
    if suffix in CODE_EXTS:
        return "code"
    if suffix in TEXT_EXTS:
        return "text"
    if suffix in ARCHIVE_EXTS:
        return "archive"
    if suffix in AUDIO_EXTS:
        return "audio"
    if suffix in VIDEO_EXTS:
        return "video"
    return "unknown"


def _extract(path: Path, kind: FileKind) -> tuple[str, str, str, str | None]:
    if kind == "image":
        return extract_image(path)
    if kind == "pdf":
        return extract_pdf(path)
    if kind == "docx":
        return extract_docx(path)
    if kind == "spreadsheet":
        return extract_xlsx(path)
    if kind in {"text", "code"}:
        return extract_text(path)
    if kind == "archive":
        return extract_archive(path)
    if kind in {"audio", "video"}:
        return extract_media(path)
    return extract_generic(path)


def _extract_safely(path: Path, kind: FileKind) -> tuple[str, str, str, str | None]:
    if kind not in ISOLATED_KINDS:
        return _extract(path, kind)
    command = (
        [sys.executable, "--extract", kind, str(path)]
        if getattr(sys, "frozen", False)
        else [sys.executable, "-m", "backend.extract_worker", kind, str(path)]
    )
    try:
        completed = subprocess.run(
            command,
            capture_output=True,
            text=True,
            timeout=EXTRACTION_TIMEOUT_SECONDS,
            check=False,
            env={**os.environ, "PYTHONPATH": str(Path(__file__).resolve().parent.parent)},
        )
    except subprocess.TimeoutExpired:
        return "", "Deep extraction timed out; metadata only.", "metadata_only", None
    if completed.returncode != 0:
        return "", "Deep extraction failed safely; metadata only.", "metadata_only", None
    try:
        payload = json.loads(completed.stdout)
        return (
            str(payload.get("preview", "")),
            str(payload.get("metadata", "")),
            str(payload.get("level", "metadata_only")),
            payload.get("image_b64"),
        )
    except (json.JSONDecodeError, AttributeError, TypeError):
        return "", "Deep extraction returned invalid output; metadata only.", "metadata_only", None


def _iter_files(
    root: Path,
    include_subfolders: bool,
    ignored_folders: set[str],
    excluded_paths: set[Path],
):
    if include_subfolders:
        for current_root_raw, dirs, files in os.walk(root):
            current_root = Path(current_root_raw)
            dirs[:] = [
                name
                for name in dirs
                if name not in ignored_folders
                and (current_root / name).resolve() not in excluded_paths
            ]
            for name in files:
                path = current_root / name
                if path.resolve() not in excluded_paths:
                    yield path
    else:
        for child in root.iterdir():
            if child.is_file() and child.resolve() not in excluded_paths:
                yield child


def scan_folder(request: ScanRequest) -> ScanResponse:
    root = Path(request.folder_path).expanduser().resolve()
    if not root.exists() or not root.is_dir():
        raise ValueError("Folder path does not exist or is not a directory.")

    ignored_exts = {ext.lower() for ext in request.ignored_extensions}
    ignored_folders = set(request.ignored_folders)
    excluded_paths = {Path(path).expanduser().resolve() for path in request.excluded_paths if path}
    max_bytes = request.max_file_size_mb * 1024 * 1024
    files: list[FileItem] = []
    summary = ScanSummary()

    for path in _iter_files(root, request.include_subfolders, ignored_folders, excluded_paths):
        try:
            if path.name == ".DS_Store" or path.suffix.lower() in ignored_exts:
                continue
            if path.is_symlink():
                try:
                    resolved = path.resolve()
                    resolved.relative_to(root)
                except Exception:
                    continue
            stat = path.stat()
            kind = detect_kind(path)
            if stat.st_size > max_bytes:
                preview = ""
                metadata = f"Skipped deep extraction because file exceeds {request.max_file_size_mb} MB."
                level = "metadata_only"
                image_b64 = None
            else:
                preview, metadata, level, image_b64 = _extract_safely(path, kind)

            file_item = FileItem(
                path=str(path),
                name=path.name,
                extension=path.suffix.lower(),
                size=stat.st_size,
                mime=mimetypes.guess_type(path.name)[0] or "application/octet-stream",
                last_modified=datetime.fromtimestamp(stat.st_mtime).astimezone().isoformat(timespec="seconds"),
                file_kind=kind,
                content_preview=preview,
                metadata_summary=metadata,
                supported_level=level,  # type: ignore[arg-type]
                image_b64=image_b64,
            )
            files.append(file_item)
            _count(summary, kind)
        except OSError:
            continue
    summary.total_files = len(files)
    return ScanResponse(scan_id="", files=files, summary=summary)


def _count(summary: ScanSummary, kind: FileKind) -> None:
    if kind == "image":
        summary.images += 1
    elif kind == "pdf":
        summary.pdfs += 1
    elif kind == "docx":
        summary.documents += 1
    elif kind in {"text", "spreadsheet"}:
        summary.text += 1
    elif kind == "code":
        summary.code += 1
    elif kind == "archive":
        summary.archives += 1
    elif kind in {"audio", "video"}:
        summary.media += 1
    else:
        summary.unsupported += 1
