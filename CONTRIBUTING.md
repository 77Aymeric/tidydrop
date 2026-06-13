# Contributing to TidyDrop

Thanks for helping make TidyDrop safer and more useful.

## Project Principles

- Local-first: files stay on the user's Mac.
- Safe-by-design: never delete, never overwrite, never apply without preview.
- User-controlled AI: Ollama can only classify into categories the user defines.
- Native macOS feel: prefer SwiftUI system controls, toolbars, sidebars and materials.
- Small, reviewable changes: avoid broad rewrites unless they reduce real risk.

## Development Setup

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
swift build
```

Run the app:

```bash
./script/build_and_run.sh
```

Run checks:

```bash
swift build
python -m pytest
python -m ruff check backend tests
```

## Pull Request Checklist

- The app still never deletes files.
- The app still never overwrites existing files.
- Any file operation remains previewable before Apply.
- Undo behavior is preserved or improved.
- New backend behavior has focused tests.
- New macOS UI uses native SwiftUI controls unless there is a specific reason not to.
- Prompt or schema changes update `docs/PROMPTS.md`.
- User-facing changes update `CHANGELOG.md` and relevant screenshots/docs.

## Pull Requests

Keep pull requests focused and explain:

- the user problem;
- the chosen behavior;
- safety implications;
- tests performed;
- screenshots for visible macOS changes.

Use the repository pull request template. Draft PRs are welcome for early feedback.

## Areas That Need Care

- Filesystem operations and conflict handling.
- Archive inspection: never extract user archives without explicit future consent.
- Symlinks: do not silently follow unsafe paths outside the selected folder.
- Ollama responses: always validate JSON and fallback on invalid categories or low confidence.
