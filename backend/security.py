from __future__ import annotations

import os
import re
import secrets
from pathlib import Path

from fastapi import Header, HTTPException

IDENTIFIER_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")


def require_session(authorization: str | None = Header(default=None)) -> None:
    expected = os.environ.get("TIDYDROP_SESSION_TOKEN", "")
    if not expected:
        raise HTTPException(status_code=503, detail="Backend session is not configured.")
    scheme, _, supplied = (authorization or "").partition(" ")
    if scheme.casefold() != "bearer" or not secrets.compare_digest(supplied, expected):
        raise HTTPException(status_code=401, detail="Invalid backend session.")


def validate_identifier(value: str, label: str) -> str:
    if not IDENTIFIER_RE.fullmatch(value):
        raise ValueError(f"Invalid {label}.")
    return value


def resolved_path(path: str | Path) -> Path:
    return Path(path).expanduser().resolve(strict=False)


def require_path_within(path: str | Path, root: str | Path, label: str) -> Path:
    candidate = resolved_path(path)
    boundary = resolved_path(root)
    try:
        candidate.relative_to(boundary)
    except ValueError as exc:
        raise ValueError(f"{label} is outside the allowed folder.") from exc
    return candidate
