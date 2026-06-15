from __future__ import annotations

from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import Depends, FastAPI, HTTPException

from backend.classifier import classify_files, discover_categories
from backend.config import OLLAMA_BASE_URL, ensure_app_dirs
from backend.history import list_runs, load_run
from backend.models import (
    ApplyRequest,
    ClassifyRequest,
    ClassifyResponse,
    DiscoverCategoriesRequest,
    DiscoverCategoriesResponse,
    PlanRequest,
    ScanRequest,
    UndoApplyRequest,
    UndoPreviewRequest,
)
from backend.ollama_client import OllamaClient, OllamaUnavailable
from backend.operations import apply_plan
from backend.planner import create_plan
from backend.scanner import scan_folder
from backend.security import require_session
from backend.state import load_scan, register_scan
from backend.undo import apply_undo, preview_undo


@asynccontextmanager
async def lifespan(_: FastAPI):
    ensure_app_dirs()
    yield


app = FastAPI(
    title="TidyDrop",
    version="0.1.0",
    dependencies=[Depends(require_session)],
    lifespan=lifespan,
)


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
        root = Path(request.folder_path).expanduser().resolve()
        return register_scan(root, scan_folder(request))
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.post("/api/classify", response_model=ClassifyResponse)
async def classify(request: ClassifyRequest):
    try:
        files = load_scan(request.scan_id).files(request.file_ids)
        return ClassifyResponse(results=await classify_files(files, request.categories, request.settings))
    except (FileNotFoundError, ValueError) as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.post("/api/categories/discover", response_model=DiscoverCategoriesResponse)
async def categories_discover(request: DiscoverCategoriesRequest):
    try:
        files = load_scan(request.scan_id).files()
        categories, added = await discover_categories(files, request.categories, request.settings)
        return DiscoverCategoriesResponse(categories=categories, added_categories=added)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Folder discovery failed: {exc}") from exc


@app.post("/api/plan")
async def plan(request: PlanRequest):
    try:
        return create_plan(request)
    except (FileNotFoundError, ValueError) as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.post("/api/apply")
async def apply(request: ApplyRequest):
    try:
        return {"run": apply_plan(request)}
    except FileNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.get("/api/history")
async def history():
    return {"runs": list_runs()}


@app.get("/api/history/{run_id}")
async def history_detail(run_id: str):
    try:
        return load_run(run_id)
    except FileNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.post("/api/undo/preview")
async def undo_preview(request: UndoPreviewRequest):
    try:
        return preview_undo(request.run_id)
    except FileNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.post("/api/undo/apply")
async def undo_apply(request: UndoApplyRequest):
    try:
        return apply_undo(request.run_id)
    except FileNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
