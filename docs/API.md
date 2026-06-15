# Local API

The native app talks to a FastAPI service bound to a random `127.0.0.1` port. It is an internal local API, not a remotely hosted service.

Every request requires the per-launch bearer token created by the native app. The port and token are communicated through a private mode-`0600` runtime file and are removed when the backend exits. An unauthenticated local process receives `401`.

## Endpoints

| Method | Path | Behavior |
| --- | --- | --- |
| `GET` | `/api/health` | Backend status and Ollama reachability |
| `GET` | `/api/ollama/models` | Names returned by Ollama `/api/tags` |
| `POST` | `/api/scan` | Read-only scan and bounded extraction |
| `POST` | `/api/categories/discover` | Semantic category discovery across a file sample |
| `POST` | `/api/classify` | Classification for trusted files from a scan session |
| `POST` | `/api/plan` | Builds copy/move operations without applying them |
| `POST` | `/api/apply` | Applies controlled edits to a server-stored plan |
| `GET` | `/api/history` | Lists saved operation plans |
| `GET` | `/api/history/{run_id}` | Loads one saved plan |
| `POST` | `/api/undo/preview` | Computes reverse operations |
| `POST` | `/api/undo/apply` | Applies the computed undo behavior |

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

The response contains an opaque `scan_id`, typed `FileItem` objects, and a summary by file kind. The server retains the canonical root and file paths for later requests. Scanning never changes the source folder.

## Category Discovery

`POST /api/categories/discover`

The request contains a `scan_id`, existing categories, and classification settings. The server selects a deterministic stratified sample across subfolders, file kinds, and dates. When AI categories are disabled, the endpoint returns the existing set with a guaranteed `To Review` category.

Discovery errors return `502` and do not create a partial operation plan.

## Classification

`POST /api/classify`

The client supplies a `scan_id` and file IDs, never trusted filesystem paths. The backend classifies the matching server-retained files sequentially through Ollama. Unknown IDs are rejected. Individual model failures become zero-confidence `To Review` results rather than aborting the complete response.

## Plan

`POST /api/plan`

The planner requires:

- a valid `scan_id`;
- category definitions;
- classification results;
- output folder;
- copy or move mode;
- renaming settings.

It returns an `OperationPlan` with no filesystem side effects and stores its canonical form under `~/.tidydrop/plans`. Run and plan IDs include random UUID material.

## Apply

`POST /api/apply`

The client sends a `plan_id` plus the reviewed enabled state, category, and proposed filename for each operation. It cannot replace source or target paths. The backend reloads the canonical plan, rejects missing or extra operation IDs and unknown categories, sanitizes names, validates source/output boundaries, and recomputes every target.

Targets are created exclusively and checked again at apply time to prevent races and overwrite. Disabled entries are skipped.

The completed plan, actual paths, statuses, conflicts, and errors are persisted in run history.

## Undo

`POST /api/undo/preview` and `POST /api/undo/apply`

Undo is based on persisted actual paths, not a new AI decision. Copy undo moves generated copies into the undo holding directory; move undo restores originals where possible.

## Errors

Validation errors use FastAPI/Pydantic responses. Missing or invalid authentication returns `401`, filesystem request errors generally return `400`, missing history/plans return `404`, and failed folder discovery returns `502`.
