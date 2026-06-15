# Development

## Toolchain

- macOS 26+
- Xcode 26+ / Swift 6.2
- Python 3.11+
- Ollama for manual AI workflow testing

## Setup

```bash
uv sync --locked --extra dev
swift build
```

## Build and Run

```bash
./script/build_and_run.sh
```

The script stops an existing TidyDrop process, builds the SwiftPM executable, creates `dist/TidyDrop.app`, and launches the native bundle.

Useful modes:

```bash
./script/build_and_run.sh --verify
./script/build_and_run.sh --logs
./script/build_and_run.sh --debug
```

## Checks

```bash
swift build
swift test
uv run ruff check backend tests
uv run pytest
```

Backend tests cover authentication, trusted scan sessions, API round trips, bounded and isolated extraction, corrupt inputs, JSON recovery, category fallback, confidence handling, conflict-safe paths, server-stored plans, copy/move behavior, history path traversal, and undo. Swift tests verify the JSON contract used by the native client.

## Local Backend

The app normally owns backend startup. For direct API development, choose a development-only token explicitly:

```bash
TIDYDROP_SESSION_TOKEN=local-development-only \
uv run uvicorn backend.main:app --host 127.0.0.1 --port 3838 --reload
```

Requests, including OpenAPI, require `Authorization: Bearer local-development-only`. The packaged app instead chooses a random port and random token automatically.

## Ollama

```bash
ollama serve
ollama pull qwen3.5:2b
ollama pull qwen3.5:9b
ollama pull gemma4:e4b-it-qat
```

Models are large and are never installed automatically. See [Model Strategy](MODELS.md) before downloading.

## Repository Layout

```text
Sources/TidyDrop/
├── App/
├── Models/
├── Services/
├── Stores/
├── Support/
└── Views/

backend/
├── extractors/
├── classifier.py
├── main.py
├── models.py
├── ollama_client.py
├── operations.py
├── planner.py
├── scanner.py
└── undo.py
```

## Change Guidelines

- Preserve copy as the default.
- Do not add deletion.
- Never overwrite an existing path.
- Keep scan and extraction read-only.
- Validate all model output.
- Keep filesystem changes behind an explicit plan and Apply action.
- Add focused tests for backend behavior changes.
- Prefer native SwiftUI/AppKit behavior over custom web-like controls.
- Update `docs/PROMPTS.md` when prompt templates or schemas change.

## Manual Smoke Test

1. Start Ollama.
2. Run `./script/build_and_run.sh --verify`.
3. Drop a temporary mixed-file folder.
4. Scan and inspect previews.
5. Enable Smart folders and classify.
6. Verify generated groups are semantic rather than extension-only.
7. Edit one category and one filename in Review Plan.
8. Apply in Copy mode.
9. Confirm originals are unchanged and history exists.
10. Preview and apply undo.

## Distribution

See [Releasing TidyDrop](RELEASING.md) for standalone packaging, Developer ID signing, notarization, DMG creation, checksums, and GitHub Release automation.
