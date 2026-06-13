from __future__ import annotations

import subprocess
from pathlib import Path

from fastapi import FastAPI, HTTPException

from backend.classifier import classify_files, discover_categories
from backend.config import OLLAMA_BASE_URL, ensure_app_dirs
from backend.history import list_runs, load_run
from backend.models import (
    ApplyRequest,
    ClassifyRequest,
    ClassifyResponse,
    DiscoverCategoriesRequest,
    DiscoverCategoriesResponse,
    OpenFolderRequest,
    PlanRequest,
    ScanRequest,
    UndoApplyRequest,
    UndoPreviewRequest,
)
from backend.ollama_client import OllamaClient, OllamaUnavailable
from backend.operations import apply_plan
from backend.planner import create_plan
from backend.scanner import scan_folder
from backend.undo import apply_undo, preview_undo

app = FastAPI(title="TidyDrop", version="0.1.0")


@app.on_event("startup")
def startup() -> None:
    ensure_app_dirs()


@app.get("/api/health")
async def health():
    client = OllamaClient()
    ollama_running = await client.health()
    return {
        "status": "ok",
        "ollama": {
            "base_url": OLLAMA_BASE_URL,
            "running": ollama_running,
            "message": "ok" if ollama_running else "Ollama is not running. Start it with: ollama serve",
        },
    }


@app.get("/api/ollama/models")
async def ollama_models():
    try:
        return {"models": await OllamaClient().models()}
    except OllamaUnavailable as exc:
        return {"models": [], "error": str(exc)}


@app.post("/api/scan")
async def scan(request: ScanRequest):
    try:
        return scan_folder(request)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.post("/api/classify", response_model=ClassifyResponse)
async def classify(request: ClassifyRequest):
    return ClassifyResponse(results=await classify_files(request.files, request.categories, request.settings))


@app.post("/api/categories/discover", response_model=DiscoverCategoriesResponse)
async def categories_discover(request: DiscoverCategoriesRequest):
    try:
        categories, added = await discover_categories(request.files, request.categories, request.settings)
        return DiscoverCategoriesResponse(categories=categories, added_categories=added)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Folder discovery failed: {exc}") from exc


@app.post("/api/plan")
async def plan(request: PlanRequest):
    return create_plan(request)


@app.post("/api/apply")
async def apply(request: ApplyRequest):
    return {"run": apply_plan(request.plan)}


@app.get("/api/history")
async def history():
    return {"runs": list_runs()}


@app.get("/api/history/{run_id}")
async def history_detail(run_id: str):
    try:
        return load_run(run_id)
    except FileNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@app.post("/api/undo/preview")
async def undo_preview(request: UndoPreviewRequest):
    try:
        return preview_undo(request.run_id)
    except FileNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@app.post("/api/undo/apply")
async def undo_apply(request: UndoApplyRequest):
    try:
        return apply_undo(request.run_id)
    except FileNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@app.post("/api/open-folder")
async def open_folder(request: OpenFolderRequest):
    path = Path(request.folder_path).expanduser()
    if not path.exists():
        raise HTTPException(status_code=404, detail="Folder does not exist.")
    subprocess.Popen(["open", str(path)])
    return {"ok": True}
