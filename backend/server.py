from __future__ import annotations

import json
import os
import secrets
import socket
from pathlib import Path
from uuid import uuid4

import uvicorn

from backend.config import APP_DIR, HOST


def run_server(app, *, access_log: bool) -> None:
    token = os.environ.get("TIDYDROP_SESSION_TOKEN") or secrets.token_urlsafe(32)
    os.environ["TIDYDROP_SESSION_TOKEN"] = token
    requested_port = int(os.environ.get("TIDYDROP_PORT", "0"))
    session_path = Path(
        os.environ.get(
            "TIDYDROP_SESSION_FILE",
            APP_DIR / "runtime" / f"session-{uuid4().hex}.json",
        )
    ).expanduser()

    listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    listener.bind((HOST, requested_port))
    listener.listen(128)
    port = listener.getsockname()[1]
    _write_session_file(session_path, port, token)

    try:
        config = uvicorn.Config(app, host=HOST, port=port, reload=False, access_log=access_log)
        uvicorn.Server(config).run(sockets=[listener])
    finally:
        session_path.unlink(missing_ok=True)
        listener.close()


def _write_session_file(path: Path, port: int, token: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.tmp")
    temporary.write_text(
        json.dumps({"port": port, "token": token, "pid": os.getpid()}),
        encoding="utf-8",
    )
    temporary.chmod(0o600)
    temporary.replace(path)
