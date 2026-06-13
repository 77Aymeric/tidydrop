# Roadmap

TidyDrop is an alpha-stage native macOS utility. Roadmap work must preserve the local-only, preview-first, never-delete safety model.

## Product Quality

- Dedicated first-run model setup and capability checks.
- Better review-table density and keyboard navigation.
- Richer result reports and exportable run summaries.
- Persisted user settings and category collections.
- More representative product screenshots and demo fixtures.
- Accessibility and VoiceOver pass.

## File Understanding

- Image thumbnails throughout review.
- Optional local OCR for scanned documents.
- Video frame sampling with strict limits.
- Richer local audio metadata.
- More archive manifest formats without extraction.
- Better date/entity linking across project files.

## AI Quality

- Evaluate folder discovery and classification on reproducible mixed-project corpora.
- Detect model capability before assigning text or vision roles.
- Improve confidence calibration using measured outcomes.
- Add duplicate/near-duplicate and version-family signals.
- Add user-approved learning from prior local runs without cloud storage.

## Performance

- Batch or cache safe repeated previews.
- Measure model loading, generation time, memory, and cancellation latency.
- Reduce redundant expert reviews.
- Add resource-aware presets for 8 GB, 16 GB, and larger Macs.

## Distribution

- Signed release builds.
- Notarized ZIP or DMG.
- Stable release automation and checksums.
- Clear bundled-backend strategy without bundling Ollama models.

## Not Planned

- Cloud upload or remote AI providers.
- Deletion workflows.
- Automatic apply without review.
- Executing discovered code.
- Silently extracting archives.
- Downloading multi-gigabyte models without explicit user action.
