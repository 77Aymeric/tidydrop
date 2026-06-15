from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from threading import RLock
from uuid import uuid4

from backend.models import FileItem, ScanResponse
from backend.security import require_path_within, validate_identifier


@dataclass(frozen=True)
class ScanSession:
    scan_id: str
    root: Path
    files_by_id: dict[str, FileItem]

    def files(self, file_ids: list[str] | None = None) -> list[FileItem]:
        if file_ids is None:
            return list(self.files_by_id.values())
        if len(file_ids) != len(set(file_ids)):
            raise ValueError("Duplicate file identifiers are not allowed.")
        try:
            return [self.files_by_id[file_id] for file_id in file_ids]
        except KeyError as exc:
            raise ValueError("A file does not belong to the active scan.") from exc


_scans: dict[str, ScanSession] = {}
_lock = RLock()


def register_scan(root: Path, response: ScanResponse) -> ScanResponse:
    scan_id = str(uuid4())
    trusted_files: dict[str, FileItem] = {}
    for file in response.files:
        trusted_path = require_path_within(file.path, root, "Scanned file")
        if not trusted_path.is_file():
            continue
        trusted = file.model_copy(update={"path": str(trusted_path)})
        trusted_files[trusted.id] = trusted
    session = ScanSession(scan_id=scan_id, root=root.resolve(), files_by_id=trusted_files)
    with _lock:
        _scans[scan_id] = session
        while len(_scans) > 12:
            _scans.pop(next(iter(_scans)))
    return response.model_copy(update={"scan_id": scan_id, "files": list(trusted_files.values())})


def load_scan(scan_id: str) -> ScanSession:
    validate_identifier(scan_id, "scan identifier")
    with _lock:
        session = _scans.get(scan_id)
    if session is None:
        raise FileNotFoundError("Scan session expired. Scan the folder again.")
    return session
