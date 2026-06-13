from __future__ import annotations

import uvicorn

from backend.config import HOST, PORT
from backend.main import app


def main() -> None:
    uvicorn.run(app, host=HOST, port=PORT, reload=False, access_log=False)


if __name__ == "__main__":
    main()
