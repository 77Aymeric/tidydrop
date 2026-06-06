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

## AI Output Validation

Ollama responses are treated as untrusted text.

TidyDrop validates that:

- the response can be parsed as JSON,
- the category exists in user-defined categories,
- confidence is above the configured threshold,
- reasons are bounded,
- ambiguous results go to `To Review`.

Invalid or low-confidence responses are fallback results, not hard failures.

## File Extraction Boundaries

Extraction is bounded and read-only:

- PDFs: first pages only.
- DOCX: sampled paragraphs only.
- Text/code: bounded character preview.
- XLSX: sheet names and sample cells.
- ZIP: internal listing only, no extraction.
- Media/unknown: metadata only.

Archives are never extracted by default.
