# Workflow

TidyDrop separates understanding from filesystem changes. Scanning, category discovery, classification, and planning are read-only. Only an explicit Apply action can copy or move files.

## Phase 1: Select a Folder

The user can choose a folder with the native file picker or drop a folder into the window. Dropped files are rejected with `Please drop a folder.`

The default output is `<source>/TidyDrop Sorted`. That path is excluded from later scans to prevent recursive sorting.

## Phase 2: Scan and Extract

The scanner:

1. resolves the source directory;
2. walks it with `pathlib` and `os.walk`;
3. skips technical folders such as `.git`, `node_modules`, `.venv`, `__pycache__`, `dist`, and `build`;
4. rejects unsafe symlink targets outside the selected root;
5. detects a file kind from the extension;
6. extracts a bounded, read-only preview;
7. returns files and a type summary to SwiftUI.

No discovered file is executed. ZIP files are listed but not extracted.

## Phase 3: Discover Semantic Folders

When Smart folders is enabled, the expert text model receives a bounded sample of up to 200 files. Each sample includes:

- filename;
- relative path;
- file kind;
- modification date;
- short metadata summary;
- bounded content excerpt.

The model proposes three to five collection-level groups. Generic groups such as `Documents`, `Code`, `Images`, or `Archives` are rejected by backend validation. Existing categories are preserved and `To Review` is guaranteed.

Discovery completes before classification. This makes the result retroactive: every file, including the first scanned file, is classified against the final category set.

## Phase 4: Fast Classification

The fast model processes files sequentially. It receives the final category list plus metadata and extracted content.

The expected result contains:

```json
{
  "category_id": "project-atlas",
  "confidence": 0.84,
  "reason": "Mentions Atlas launch assets and the same client as the brief.",
  "suggested_filename": "atlas-launch-brief-2026.pdf",
  "needs_review": false
}
```

The backend validates category IDs, confidence, reasons, and filename extensions. A reason based only on file type is capped at `0.35`.

## Phase 5: Expert Review

Results are escalated when they are uncertain, generic, marked for review, or have weak filename proposals. Text and image files can use different expert models.

The expert result replaces the fast result only when it is judged better by the app's acceptance rules. Models are unloaded between phases to lower memory pressure.

## Phase 6: Build a Plan

The planner combines files, categories, classifications, and settings into immutable-looking operation entries with:

- source path;
- destination path;
- mode;
- category;
- proposed filename;
- confidence;
- reason;
- conflict metadata;
- enabled state.

No filesystem change happens here. Existing destinations are converted to alternate paths.

## Phase 7: Human Review

The user can:

- preview extracted text or an image;
- open the original file;
- reveal it in Finder;
- change its category;
- edit the proposed filename;
- disable the operation;
- inspect confidence and reasoning.

Edits update the final target path before Apply.

## Phase 8: Apply

Apply processes only enabled plan entries:

- `copy` uses `shutil.copy2`;
- `move` uses `shutil.move`;
- parent folders are created as needed;
- a final target existence check prevents overwrite;
- every status and actual path is written to run history.

## Phase 9: Undo

Undo is previewed before it is applied.

- Move runs restore files toward their original paths in reverse order.
- Copy runs move generated copies into `~/.tidydrop/undone/<run_id>/`.
- Existing undo destinations receive alternate names.
- Missing or conflicting files are reported instead of overwritten.

## Cancellation and Resource Control

The native app displays the current phase, file, model, completed count, and activity log. Long-running work can be stopped from the UI.

Ollama calls have a configurable timeout from 15 to 600 seconds. The default is 120 seconds. Image bytes are loaded only for vision requests, and images above the configured vision limit are rejected.
