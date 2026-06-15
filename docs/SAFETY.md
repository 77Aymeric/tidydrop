# Safety Model

TidyDrop is intentionally conservative. It is an AI-assisted sorter, not an autonomous file cleaner.

## Non-Negotiable Rules

- Never delete files.
- Never overwrite files.
- Never move or copy without a preview.
- Never apply without explicit confirmation.
- Never send files to a cloud service.
- Never execute discovered files or code.
- Never invent AI categories.
- Always keep run history.
- Always provide undo for completed operations.
- Never download models without explicit user action.

## Copy Mode

Copy mode is the default.

Undo for copy mode does not delete copied files. Instead, TidyDrop moves copied files into:

```text
~/.tidydrop/undone/<run_id>/
```

This keeps the “never delete” guarantee intact.

## Move Mode

Move mode is available for users who explicitly choose it. Undo processes completed operations in reverse order and attempts to move files back to their original path.

If the original path already exists, TidyDrop must avoid overwriting and choose an alternate safe path or mark the operation as conflicted.

## Conflict Handling

Before applying a plan, target paths are checked. If a target exists, TidyDrop chooses an alternate filename such as:

```text
Document (1).pdf
```

If an operation cannot be performed safely, it is marked as skipped, missing, conflict or error. It should not fail silently.

The preview also reserves targets across the complete plan, so two operations proposing the same path are shown as a conflict before Apply. Apply uses exclusive file creation and repeats conflict resolution to cover filesystem races.

## AI Output Validation

Ollama responses are treated as untrusted text.

TidyDrop validates that:

- the response can be parsed as JSON,
- the category exists in user-defined categories,
- confidence is above the configured threshold,
- reasons are bounded,
- ambiguous results go to `To Review`.

Invalid or low-confidence responses are fallback results, not hard failures.

Reasons that rely on file type or extension without semantic evidence are capped at `0.35` confidence. AI-created generic folders are rejected before classification.

## File Extraction Boundaries

Extraction is bounded and read-only:

- PDFs: first pages only.
- DOCX: sampled paragraphs only.
- Text/code: bounded character preview.
- XLSX: sheet names and sample cells.
- ZIP: internal listing only, no extraction.
- Media/unknown: metadata only.

Archives are never extracted by default.

PDF, DOCX, XLSX, and archive parsers run in a child process with an 8-second parent timeout plus CPU, address-space, and output-size limits where macOS supports them. Corrupt, pathological, or timed-out inputs fall back to metadata-only summaries.

## Local Network Boundary

The FastAPI engine binds to a random port on `127.0.0.1`. Each launch uses a cryptographically random bearer token known only to the native app and backend. Canonical scan roots, file paths, and plans stay server-side; Apply cannot supply arbitrary source or destination paths. History and plan identifiers are validated before they become filenames.

Ollama is expected at `localhost:11434`. TidyDrop contains no cloud provider integration.

Prompts may contain local absolute paths and bounded excerpts because they remain on the local machine. The selected local models are part of the user's trusted environment.

## Model and Memory Safety

- Models are never downloaded automatically.
- Image bytes are loaded lazily for vision requests.
- Large images are rejected for vision analysis.
- Requests use configurable timeouts.
- Long workflows expose a Stop action.
- Models are unloaded between major phases where possible.
