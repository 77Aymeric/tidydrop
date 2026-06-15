from __future__ import annotations

from datetime import datetime
from pathlib import Path
from typing import Literal
from uuid import uuid4

from pydantic import BaseModel, Field


FileKind = Literal[
    "image",
    "pdf",
    "docx",
    "text",
    "spreadsheet",
    "code",
    "archive",
    "audio",
    "video",
    "unknown",
]
SupportedLevel = Literal["full", "partial", "metadata_only", "unsupported"]
OperationStatus = Literal["pending", "done", "skipped", "conflict", "missing", "error"]
RunMode = Literal["copy", "move"]


class Category(BaseModel):
    id: str
    name: str
    description: str = ""
    rules: str = ""


class FileItem(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid4()))
    path: str
    name: str
    extension: str
    size: int
    mime: str = "application/octet-stream"
    last_modified: str
    file_kind: FileKind
    content_preview: str = ""
    metadata_summary: str = ""
    thumbnail: str | None = None
    supported_level: SupportedLevel = "metadata_only"
    image_b64: str | None = None


class ScanRequest(BaseModel):
    folder_path: str
    include_subfolders: bool = True
    ignored_extensions: list[str] = Field(default_factory=list)
    excluded_paths: list[str] = Field(default_factory=list)
    ignored_folders: list[str] = Field(
        default_factory=lambda: [".git", "node_modules", ".venv", "__pycache__", "dist", "build", "TidyDrop Sorted"]
    )
    max_file_size_mb: int = 50


class ScanSummary(BaseModel):
    total_files: int = 0
    images: int = 0
    pdfs: int = 0
    documents: int = 0
    text: int = 0
    code: int = 0
    archives: int = 0
    media: int = 0
    unsupported: int = 0


class ScanResponse(BaseModel):
    scan_id: str
    files: list[FileItem]
    summary: ScanSummary


class ClassificationSettings(BaseModel):
    model: str = ""
    text_model: str = ""
    vision_model: str = ""
    ai_timeout_seconds: int = Field(default=120, ge=15, le=600)
    confidence_threshold: float = 0.75
    suggest_renaming: bool = True
    allow_ai_categories: bool = False
    max_ai_categories: int = 5
    fallback_category_id: str = "review"
    global_user_instructions: str = ""


class ClassifyRequest(BaseModel):
    scan_id: str
    file_ids: list[str]
    categories: list[Category]
    settings: ClassificationSettings = Field(default_factory=ClassificationSettings)


class ClassificationResult(BaseModel):
    file_id: str
    original_path: str
    suggested_category_id: str
    confidence: float
    reason: str
    suggested_filename: str | None = None
    should_rename: bool = False
    needs_review: bool = False


class ClassifyResponse(BaseModel):
    results: list[ClassificationResult]


class DiscoverCategoriesRequest(BaseModel):
    scan_id: str
    categories: list[Category]
    settings: ClassificationSettings = Field(default_factory=ClassificationSettings)


class DiscoverCategoriesResponse(BaseModel):
    categories: list[Category]
    added_categories: list[Category]


class PlanSettings(BaseModel):
    mode: RunMode = "copy"
    output_folder: str
    suggest_renaming: bool = True
    apply_renaming: bool = False


class PlanRequest(BaseModel):
    scan_id: str
    categories: list[Category]
    results: list[ClassificationResult]
    settings: PlanSettings


class PlanConflict(BaseModel):
    type: str
    message: str


class OperationEntry(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid4()))
    type: RunMode
    enabled: bool = True
    original_path: str
    target_path: str
    actual_path: str | None = None
    category_id: str
    suggested_filename: str | None = None
    confidence: float = 0
    reason: str = ""
    status: OperationStatus = "pending"
    undo_status: str = "not_undone"
    conflict: PlanConflict | None = None
    error: str | None = None


class OperationPlan(BaseModel):
    plan_id: str
    run_id: str
    created_at: str
    source_folder: str
    output_folder: str
    mode: RunMode
    operations: list[OperationEntry]


class OperationEdit(BaseModel):
    operation_id: str
    enabled: bool = True
    category_id: str
    suggested_filename: str | None = None


class ApplyRequest(BaseModel):
    plan_id: str
    edits: list[OperationEdit]


class ApplyResponse(BaseModel):
    run: OperationPlan


class RunHistoryItem(BaseModel):
    run_id: str
    created_at: str
    source_folder: str
    output_folder: str
    mode: RunMode
    operations: list[OperationEntry]


class UndoPreviewRequest(BaseModel):
    run_id: str


class UndoAction(BaseModel):
    operation_id: str
    original_path: str
    current_path: str | None
    undo_target_path: str | None
    status: OperationStatus = "pending"
    message: str = ""


class UndoPreview(BaseModel):
    run_id: str
    mode: RunMode
    actions: list[UndoAction]


class UndoApplyRequest(BaseModel):
    run_id: str


def utc_now_id() -> tuple[str, str]:
    now = datetime.now().astimezone()
    suffix = uuid4().hex[:10]
    return f"{now.strftime('%Y-%m-%d_%H-%M-%S')}-{suffix}", now.isoformat(timespec="seconds")


def path_to_id(path: Path) -> str:
    return str(uuid4())
