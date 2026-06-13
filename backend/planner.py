from __future__ import annotations

import re
from pathlib import Path

from backend.models import OperationEntry, OperationPlan, PlanConflict, PlanRequest, utc_now_id


def create_plan(request: PlanRequest) -> OperationPlan:
    run_id, created_at = utc_now_id()
    files_by_id = {file.id: file for file in request.files}
    categories_by_id = {category.id: category for category in request.categories}
    operations: list[OperationEntry] = []
    for result in request.results:
        file = files_by_id.get(result.file_id)
        category = categories_by_id.get(result.suggested_category_id)
        if file is None or category is None:
            continue
        filename = file.name
        if request.settings.apply_renaming and result.suggested_filename:
            filename = sanitize_filename(result.suggested_filename, fallback=file.name)
            if file.extension:
                filename = f"{Path(filename).stem}{file.extension}"
        target_dir = Path(request.settings.output_folder).expanduser() / sanitize_filename(category.name, fallback=category.id)
        target_path = target_dir / filename
        conflict = None
        if target_path.exists():
            alt = alternate_path(target_path)
            conflict = PlanConflict(type="target_exists", message=f"Target exists; using {alt.name}.")
            target_path = alt
        operations.append(
            OperationEntry(
                type=request.settings.mode,
                original_path=file.path,
                target_path=str(target_path),
                category_id=category.id,
                suggested_filename=result.suggested_filename,
                confidence=result.confidence,
                reason=result.reason,
                conflict=conflict,
            )
        )
    return OperationPlan(
        run_id=run_id,
        created_at=created_at,
        source_folder=request.source_folder,
        output_folder=request.settings.output_folder,
        mode=request.settings.mode,
        operations=operations,
    )


def sanitize_filename(name: str, fallback: str) -> str:
    cleaned = re.sub(r"[/:\\\0]+", "-", name).strip().strip(".")
    return cleaned or fallback


def alternate_path(path: Path) -> Path:
    if not path.exists():
        return path
    stem = path.stem
    suffix = path.suffix
    for index in range(1, 10_000):
        candidate = path.with_name(f"{stem} ({index}){suffix}")
        if not candidate.exists():
            return candidate
    raise FileExistsError(f"Could not find available target path for {path}")
