## What changed

Describe the user-facing or technical change.

## Why

Explain the problem and the intended outcome.

## Safety checklist

- [ ] Copy remains the default.
- [ ] No delete behavior was introduced.
- [ ] Existing files cannot be overwritten.
- [ ] Filesystem changes still require an explicit reviewed plan.
- [ ] Model output is validated before use.
- [ ] Undo behavior is preserved or improved.

## Verification

- [ ] `swift build`
- [ ] `python -m ruff check backend tests`
- [ ] `python -m pytest`
- [ ] Manual native app smoke test, when relevant

## Screenshots

Add before/after screenshots for visible macOS changes.

## Documentation

- [ ] Relevant docs were updated.
- [ ] `docs/PROMPTS.md` was updated for prompt/schema changes.
- [ ] `CHANGELOG.md` was updated for notable changes.
