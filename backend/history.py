from __future__ import annotations

import json
from pathlib import Path

from backend.config import RUNS_DIR, ensure_app_dirs
from backend.models import OperationPlan


def save_run(plan: OperationPlan) -> None:
    ensure_app_dirs()
    path = RUNS_DIR / f"{plan.run_id}.json"
    path.write_text(plan.model_dump_json(indent=2), encoding="utf-8")


def list_runs() -> list[OperationPlan]:
    ensure_app_dirs()
    runs: list[OperationPlan] = []
    for path in sorted(RUNS_DIR.glob("*.json"), reverse=True):
        try:
            runs.append(load_run(path.stem))
        except Exception:
            continue
    return runs


def load_run(run_id: str) -> OperationPlan:
    ensure_app_dirs()
    path = _run_path(run_id)
    data = json.loads(path.read_text(encoding="utf-8"))
    return OperationPlan.model_validate(data)


def _run_path(run_id: str) -> Path:
    path = RUNS_DIR / f"{run_id}.json"
    if not path.exists():
        raise FileNotFoundError(f"Run {run_id} was not found.")
    return path
