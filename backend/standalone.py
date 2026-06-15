from __future__ import annotations

import sys

from backend.extract_worker import main as extract_worker_main
from backend.main import app
from backend.server import run_server


def main() -> None:
    if len(sys.argv) > 1 and sys.argv[1] == "--extract":
        sys.argv = [sys.argv[0], *sys.argv[2:]]
        extract_worker_main()
        return
    run_server(app, access_log=False)


if __name__ == "__main__":
    main()
