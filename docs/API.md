# Local API

The native app talks to a FastAPI service bound to `127.0.0.1:3838`. It is an internal local API, not a remotely hosted service.

Interactive OpenAPI documentation is available at `http://127.0.0.1:3838/docs` while the backend is running.

## Endpoints

| Method | Path | Behavior |
| --- | --- | --- |
| `GET` | `/api/health` | Backend status and Ollama reachability |
| `GET` | `/api/ollama/models` | Names returned by Ollama `/api/tags` |
| `POST` | `/api/scan` | Read-only scan and bounded extraction |
| `POST` | `/api/categories/discover` | Semantic category discovery across a file sample |
| `POST` | `/api/classify` | Classification for supplied files and categories |
| `POST` | `/api/plan` | Builds copy/move operations without applying them |
| `POST` | `/api/apply` | Applies enabled entries from an explicit plan |
| `GET` | `/api/history` | Lists saved operation plans |
| `GET` | `/api/history/{run_id}` | Loads one saved plan |
| `POST` | `/api/undo/preview` | Computes reverse operations |
| `POST` | `/api/undo/apply` | Applies the computed undo behavior |
| `POST` | `/api/open-folder` | Opens an existing local folder with Finder |

## Scan

`POST /api/scan`

```json
{
  "folder_path": "/Users/example/Downloads",
  "include_subfolders": true,
  "ignored_extensions": [".tmp", ".lock"],
  "excluded_paths": ["/Users/example/Downloads/TidyDrop Sorted"],
  "max_file_size_mb": 50
}
```

The response contains typed `FileItem` objects and a summary by file kind. Scanning never changes the source folder.

## Category Discovery

`POST /api/categories/discover`

The request contains scanned files, existing categories, and classification settings. When AI categories are disabled, the endpoint returns the existing set with a guaranteed `To Review` category.

Discovery errors return `502` and do not create a partial operation plan.

## Classification

`POST /api/classify`

The backend classifies supplied files sequentially through Ollama. Individual model failures become zero-confidence `To Review` results rather than aborting the complete response.

## Plan

`POST /api/plan`

The planner requires:

- source folder;
- scanned files;
- category definitions;
- classification results;
- output folder;
- copy or move mode;
- renaming settings.

It returns an `OperationPlan` with no filesystem side effects.

## Apply

`POST /api/apply`

Only the supplied explicit plan is applied. Disabled entries are skipped. Targets are checked again at apply time to prevent races and overwrite.

The completed plan, actual paths, statuses, conflicts, and errors are persisted in run history.

## Undo

`POST /api/undo/preview` and `POST /api/undo/apply`

Undo is based on persisted actual paths, not a new AI decision. Copy undo moves generated copies into the undo holding directory; move undo restores originals where possible.

## Errors

Validation errors use FastAPI/Pydantic responses. Filesystem request errors generally return `400`, missing history/folders return `404`, and failed folder discovery returns `502`.
