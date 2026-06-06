# Architecture

TidyDrop is a native macOS app with a local Python engine.

## High-Level Shape

```text
TidyDrop.app (SwiftUI)
  -> starts local backend process
  -> calls http://127.0.0.1:3838/api/*

FastAPI backend
  -> scans folders
  -> extracts safe previews
  -> calls local Ollama
  -> creates operation plans
  -> applies copy/move operations
  -> writes history and undo data

Ollama
  -> runs locally at http://localhost:11434
```

There is no web UI and no cloud service.

## macOS App

Source: `Sources/TidyDrop`

- `App/`: app entrypoint and macOS scene setup.
- `Views/`: SwiftUI screens and panels.
- `Stores/`: observable app state and user workflows.
- `Services/`: local backend process and API client.
- `Models/`: shared Swift data contracts.
- `Support/`: formatting and UI compatibility helpers.

The app uses `NavigationSplitView`, native toolbar actions, SwiftUI forms, and system materials. Liquid Glass is applied through a compatibility helper so the UI stays native and adaptive.

## Backend

Source: `backend`

- `main.py`: FastAPI routes.
- `scanner.py`: folder traversal, file kind detection, ignored folders, symlink boundary checks.
- `extractors/`: bounded previews for file types.
- `ollama_client.py`: local Ollama health, model listing and generation.
- `classifier.py`: validation and fallback handling for AI output.
- `planner.py`: safe target path generation.
- `operations.py`: copy/move apply logic.
- `history.py`: run persistence.
- `undo.py`: undo preview and apply logic.

## Data Storage

TidyDrop writes app data under the user's home directory:

- `~/.tidydrop/config.json`
- `~/.tidydrop/runs/<run_id>.json`
- `~/.tidydrop/undone/<run_id>/`

## API Surface

The backend exposes local-only HTTP endpoints:

- `GET /api/health`
- `GET /api/ollama/models`
- `POST /api/scan`
- `POST /api/classify`
- `POST /api/plan`
- `POST /api/apply`
- `GET /api/history`
- `GET /api/history/{run_id}`
- `POST /api/undo/preview`
- `POST /api/undo/apply`
- `POST /api/open-folder`

## Why Keep Python?

Python keeps extraction and file handling simple while the macOS app stays native. The boundary is narrow: SwiftUI owns the product experience; FastAPI owns the local engine.
