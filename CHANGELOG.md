# Changelog

All notable changes to TidyDrop will be documented here.

The project is pre-1.0 and currently follows an evolving alpha workflow.

## Unreleased

No unreleased changes yet.

## [0.1.0-alpha.1] - 2026-06-14

### Added

- Standalone macOS release packaging with an embedded Python backend.
- Developer ID signing, Apple notarization, DMG/ZIP, checksums, and GitHub Release automation.
- Native TidyDrop application icon.
- Native macOS SwiftUI application with local FastAPI engine management.
- Native folder drag and drop, file rejection, and drag highlighting.
- Bounded extraction for images, PDF, DOCX, text, code, XLSX, ZIP, media, and unknown files.
- Local Ollama model discovery, structured classification, and vision requests.
- Collection-level semantic folder discovery.
- Fast-model pass followed by selective expert text and vision review.
- Editable review plan with preview, Open, and Show in Finder actions.
- Semantic filename suggestions with original-extension preservation.
- Copy and move application modes with conflict-safe targets.
- Run history, undo preview, and undo apply.
- Stop controls, progress phases, activity details, timeouts, and model unloading.
- Ready-to-use sorting templates.
- Simplified essential settings with advanced controls under More Settings.

### Safety

- Copy remains the default.
- No delete operation exists.
- Existing files are never overwritten.
- Apply requires an explicit plan and user confirmation.
- Copy undo moves generated files to a holding folder instead of deleting them.

### Distribution

- Published a standalone Apple Silicon DMG and ZIP on GitHub Releases.
- Signed the app and nested native backend libraries with Developer ID.
- Enabled the hardened runtime.
- Notarized both the application and DMG with Apple.
- Stapled notarization tickets to the distributed artifacts.
- Published SHA-256 checksums for release verification.

[0.1.0-alpha.1]: https://github.com/77Aymeric/tidydrop/releases/tag/v0.1.0-alpha.1
