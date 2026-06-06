# Local API

The API is intended for the native macOS app. It binds to `127.0.0.1:3838`.

## Health

```http
GET /api/health
```

Returns backend status and whether local Ollama is reachable.

## Models

```http
GET /api/ollama/models
```

Lists installed Ollama models.

## Scan

```http
POST /api/scan
```

Scans a local folder and returns `FileItem` objects plus a summary. Scanning is read-only.

## Classify

```http
POST /api/classify
```

Classifies scanned files into user-defined categories through local Ollama. Invalid AI output falls back to review.

## Plan

```http
POST /api/plan
```

Creates safe copy/move operations from classification results.

## Apply

```http
POST /api/apply
```

Applies enabled operations. The backend never deletes or overwrites files.

## History

```http
GET /api/history
GET /api/history/{run_id}
```

Lists previous runs and returns run details.

## Undo

```http
POST /api/undo/preview
POST /api/undo/apply
```

Previews and applies undo operations for a previous run.
