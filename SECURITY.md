# Security Policy

TidyDrop is designed for local-first file sorting. Security and privacy issues are treated seriously because the app works with personal folders.

## Supported Versions

The project is currently pre-1.0. Security fixes are made on `main`.

## Reporting a Vulnerability

Please open a private GitHub security advisory if available, or create an issue with a minimal description that avoids exposing sensitive local file paths or personal data.

Useful details:

- macOS version
- TidyDrop commit
- whether Ollama was running
- the file operation mode (`copy` or `move`)
- what safety guarantee was affected

## Security Guarantees

TidyDrop must preserve these guarantees:

- No cloud upload of user files.
- No deletion feature.
- No overwrite of existing files.
- No apply without preview and explicit confirmation.
- No invented categories from AI output.
- Undo support for completed runs.
- No archive extraction without a future explicit confirmation flow.
- No execution of discovered files or code.

## Out of Scope

TidyDrop does not sandbox Ollama models. Users should only install and run Ollama models they trust.
