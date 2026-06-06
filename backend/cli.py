from __future__ import annotations

import uvicorn

from backend.config import HOST, PORT


def main() -> None:
    uvicorn.run("backend.main:app", host=HOST, port=PORT, reload=False)
