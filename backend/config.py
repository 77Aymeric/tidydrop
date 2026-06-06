from __future__ import annotations

from pathlib import Path

APP_NAME = "TidyDrop"
HOST = "127.0.0.1"
PORT = 3838
OLLAMA_BASE_URL = "http://localhost:11434"
APP_DIR = Path.home() / ".tidydrop"
RUNS_DIR = APP_DIR / "runs"
UNDONE_DIR = APP_DIR / "undone"
CONFIG_PATH = APP_DIR / "config.json"
MAX_PREVIEW_CHARS = 6000
MAX_IMAGE_BYTES = 8 * 1024 * 1024


def ensure_app_dirs() -> None:
    RUNS_DIR.mkdir(parents=True, exist_ok=True)
    UNDONE_DIR.mkdir(parents=True, exist_ok=True)
    CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
    if not CONFIG_PATH.exists():
        CONFIG_PATH.write_text('{"version": 1}\n', encoding="utf-8")
