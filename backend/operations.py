from __future__ import annotations

import shutil
from pathlib import Path

from backend.history import save_run
from backend.models import OperationPlan
from backend.planner import alternate_path


def apply_plan(plan: OperationPlan) -> OperationPlan:
    for operation in plan.operations:
        if not operation.enabled:
            operation.status = "skipped"
            continue
        source = Path(operation.original_path)
        target = Path(operation.target_path)
        if not source.exists():
            operation.status = "missing"
            operation.error = "Original file is missing."
            continue
        if target.exists():
            target = alternate_path(target)
            operation.target_path = str(target)
        target.parent.mkdir(parents=True, exist_ok=True)
        try:
            if operation.type == "copy":
                shutil.copy2(source, target)
            else:
                shutil.move(str(source), str(target))
            operation.actual_path = str(target)
            operation.status = "done"
        except Exception as exc:
            operation.status = "error"
            operation.error = str(exc)
    save_run(plan)
    return plan
