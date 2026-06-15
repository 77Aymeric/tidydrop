from __future__ import annotations

import json
import resource
import sys
from pathlib import Path

from backend.scanner import _extract

MEMORY_LIMIT_BYTES = 512 * 1024 * 1024
CPU_LIMIT_SECONDS = 6


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: extract_worker <kind> <path>")
    kind = sys.argv[1]
    path = Path(sys.argv[2])
    _limit_resources()
    preview, metadata, level, image_b64 = _extract(path, kind)  # type: ignore[arg-type]
    print(
        json.dumps(
            {
                "preview": preview,
                "metadata": metadata,
                "level": level,
                "image_b64": image_b64,
            },
            ensure_ascii=False,
        )
    )


def _limit_resources() -> None:
    try:
        resource.setrlimit(resource.RLIMIT_CPU, (CPU_LIMIT_SECONDS, CPU_LIMIT_SECONDS))
    except (ValueError, OSError):
        pass
    try:
        resource.setrlimit(resource.RLIMIT_AS, (MEMORY_LIMIT_BYTES, MEMORY_LIMIT_BYTES))
    except (ValueError, OSError):
        pass
    try:
        resource.setrlimit(resource.RLIMIT_FSIZE, (16 * 1024 * 1024, 16 * 1024 * 1024))
    except (ValueError, OSError):
        pass


if __name__ == "__main__":
    main()
