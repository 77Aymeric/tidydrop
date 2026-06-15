from __future__ import annotations

from backend.main import app
from backend.server import run_server


def main() -> None:
    run_server(app, access_log=True)
