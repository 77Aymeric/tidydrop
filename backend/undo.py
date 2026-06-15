from __future__ import annotations

import shutil
from pathlib import Path

from backend.config import UNDONE_DIR, ensure_app_dirs
from backend.history import load_run, save_run
from backend.models import UndoAction, UndoPreview
from backend.planner import alternate_path
from backend.security import require_path_within


def preview_undo(run_id: str) -> UndoPreview:
    run = load_run(run_id)
    actions: list[UndoAction] = []
    for operation in reversed(run.operations):
        current = operation.actual_path or operation.target_path
        current_path = Path(current)
        if operation.status != "done":
            actions.append(
                UndoAction(
                    operation_id=operation.id,
                    original_path=operation.original_path,
                    current_path=current,
                    undo_target_path=None,
                    status="skipped",
                    message="Operation was not completed.",
                )
            )
            continue
        if not current_path.exists():
            status = "missing"
            message = "Moved/copied file is missing."
            target = None
        elif run.mode == "move":
            target_path = require_path_within(operation.original_path, run.source_folder, "Undo target")
            target = str(alternate_path(target_path) if target_path.exists() else target_path)
            status = "pending"
            message = "Will restore file to original path."
        else:
            require_path_within(current_path, run.output_folder, "Applied file")
            target_path = require_path_within(
                UNDONE_DIR / run.run_id / current_path.name,
                UNDONE_DIR / run.run_id,
                "Undo holding path",
            )
            target = str(alternate_path(target_path) if target_path.exists() else target_path)
            status = "pending"
            message = "Will move copy to the undo holding folder."
        actions.append(
            UndoAction(
                operation_id=operation.id,
                original_path=operation.original_path,
                current_path=current,
                undo_target_path=target,
                status=status,
                message=message,
            )
        )
    return UndoPreview(run_id=run_id, mode=run.mode, actions=actions)


def apply_undo(run_id: str) -> UndoPreview:
    ensure_app_dirs()
    run = load_run(run_id)
    preview = preview_undo(run_id)
    operations_by_id = {operation.id: operation for operation in run.operations}
    for action in preview.actions:
        operation = operations_by_id.get(action.operation_id)
        if action.status != "pending" or not action.current_path or not action.undo_target_path or not operation:
            continue
        source = Path(action.current_path)
        target = Path(action.undo_target_path)
        if run.mode == "move":
            require_path_within(source, run.output_folder, "Applied file")
            require_path_within(target, run.source_folder, "Undo target")
        else:
            require_path_within(source, run.output_folder, "Applied file")
            require_path_within(target, UNDONE_DIR / run.run_id, "Undo holding path")
        if not source.exists():
            action.status = "missing"
            action.message = "File disappeared before undo."
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        try:
            shutil.move(str(source), str(target))
            action.status = "done"
            action.message = "Undo operation completed."
            operation.undo_status = "undone"
        except Exception as exc:
            action.status = "error"
            action.message = str(exc)
    save_run(run)
    return preview
