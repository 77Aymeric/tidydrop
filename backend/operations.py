from __future__ import annotations

import shutil
from pathlib import Path

from backend.history import save_run
from backend.models import ApplyRequest, OperationEdit, OperationPlan, PlanConflict
from backend.planner import delete_pending_plan, load_pending_plan, sanitize_filename
from backend.security import require_path_within


def apply_plan(request: ApplyRequest) -> OperationPlan:
    stored = load_pending_plan(request.plan_id)
    plan = stored.plan.model_copy(deep=True)
    categories = {category.id: category for category in stored.categories}
    edits = _validated_edits(plan, request.edits)
    reserved: set[Path] = set()

    for operation in plan.operations:
        edit = edits[operation.id]
        operation.enabled = edit.enabled
        operation.category_id = edit.category_id
        operation.suggested_filename = edit.suggested_filename
        if not operation.enabled:
            operation.status = "skipped"
            continue

        source = require_path_within(operation.original_path, plan.source_folder, "Source file")
        if not source.is_file():
            operation.status = "missing"
            operation.error = "Original file is missing or is not a regular file."
            continue
        category = categories[edit.category_id]
        original_name = source.name
        filename = original_name
        if stored.apply_renaming and edit.suggested_filename:
            filename = sanitize_filename(edit.suggested_filename, fallback=original_name)
            if source.suffix:
                filename = f"{Path(filename).stem}{source.suffix}"
        category_name = sanitize_filename(category.name, fallback=category.id)
        requested_target = Path(plan.output_folder) / category_name / filename
        target = require_path_within(requested_target, plan.output_folder, "Target file")

        try:
            actual = _copy_without_overwrite(source, target, reserved)
            if plan.mode == "move":
                source.unlink()
            operation.target_path = str(actual)
            operation.actual_path = str(actual)
            if actual != requested_target and operation.conflict is None:
                operation.conflict = PlanConflict(
                    type="target_exists",
                    message=f"Used conflict-safe name {actual.name}.",
                )
            operation.status = "done"
        except Exception as exc:
            operation.status = "error"
            operation.error = str(exc)

    save_run(plan)
    delete_pending_plan(plan.plan_id)
    return plan


def _validated_edits(plan: OperationPlan, edits: list[OperationEdit]) -> dict[str, OperationEdit]:
    operation_ids = {operation.id for operation in plan.operations}
    edit_map = {edit.operation_id: edit for edit in edits}
    if len(edit_map) != len(edits) or set(edit_map) != operation_ids:
        raise ValueError("Apply edits must match the stored plan exactly.")
    stored = load_pending_plan(plan.plan_id)
    category_ids = {category.id for category in stored.categories}
    if any(edit.category_id not in category_ids for edit in edits):
        raise ValueError("Apply contains an unknown category.")
    return edit_map


def _copy_without_overwrite(source: Path, requested: Path, reserved: set[Path]) -> Path:
    requested.parent.mkdir(parents=True, exist_ok=True)
    for index in range(10_000):
        target = requested if index == 0 else requested.with_name(f"{requested.stem} ({index}){requested.suffix}")
        if target in reserved:
            continue
        try:
            with target.open("xb") as destination, source.open("rb") as origin:
                shutil.copyfileobj(origin, destination, length=1024 * 1024)
            shutil.copystat(source, target, follow_symlinks=False)
            reserved.add(target)
            return target
        except FileExistsError:
            continue
        except Exception:
            target.unlink(missing_ok=True)
            raise
    raise FileExistsError(f"Could not find available target path for {requested}")
