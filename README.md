# TidyDrop

**Drop a folder. Let local AI tidy it.**

TidyDrop is a native macOS utility for safe, local AI-assisted file sorting. It scans a folder, extracts bounded previews from many file types, asks local Ollama models to classify files into categories you define, and shows a complete before/after plan before any copy or move happens.

TidyDrop is not a cloud file organizer and not an automatic cleaner. It is designed to be calm, inspectable and reversible.

## Highlights

- Native macOS SwiftUI app with a simple Liquid Glass-inspired interface.
- Local-only classification through Ollama.
- Drag a folder into the window to start.
- Ready-to-use templates for downloads, school, developer files, photos and admin papers.
- Full review plan before apply.
- Copy by default.
- No deletion feature.
- No overwrite behavior.
- Run history and undo.
- Broad file support, including images, PDF, DOCX, text, code, XLSX, ZIP, media and unknown files.

## Safety Guarantees

TidyDrop is built around a visible Safe Mode:

- Local only
- Copy by default
- Never deletes
- Never overwrites
- Preview before apply
- Undo enabled

If AI confidence is low, or if the model returns invalid output, files are sent to the fallback category `To Review`.

## Requirements

- macOS 26+
- Xcode 26+
- Python 3.11+
- Ollama for classification

Scanning and preview generation work without Ollama. Classification requires Ollama running locally:

```bash
ollama serve
```

Install at least one text model:

```bash
ollama pull llama3.1
```

For image classification, install a vision-capable model:

```bash
ollama pull llama3.2-vision
```

## Quick Start

```bash
git clone https://github.com/77Aymeric/tidydrop.git
cd tidydrop

python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -e ".[dev]"

./script/build_and_run.sh
```

The script builds `dist/TidyDrop.app` and opens it. The app starts its local Python backend automatically. There is no browser UI.

## What It Can Sort

TidyDrop scans all regular files in the selected folder, with safe bounded extraction:

| Type | Current understanding |
| --- | --- |
| Images | Metadata plus base64 payload for local vision models when small enough |
| PDF | Text from the first pages |
| DOCX | Sampled paragraphs |
| TXT, MD, CSV, JSON, XML, YAML | Bounded text preview |
| Code | Extension detection plus first lines |
| XLSX | Sheet names and sample cells |
| ZIP | Internal file listing only, no extraction |
| Audio/video | Metadata only |
| Unknown/binary | Name, extension, size, path and dates |

## Sorting Templates

The native app includes starter templates:

- Downloads Cleanup
- Student Mode
- Developer Mode
- Photo Cleanup
- Admin Papers

Every template includes `To Review` as a fallback category.

## Project Structure

```text
Sources/TidyDrop/   Native macOS SwiftUI app
backend/            Local FastAPI engine for scan/classify/plan/apply/undo
tests/              Backend safety and workflow tests
script/             Build and run entrypoints
docs/               Architecture, safety, API and roadmap notes
```

## Development

Run checks locally:

```bash
swift build
python -m pytest
python -m ruff check backend tests
```

Run the packaged local app:

```bash
./script/build_and_run.sh --verify
```

More detail:

- [Architecture](docs/ARCHITECTURE.md)
- [Safety Model](docs/SAFETY.md)
- [Local API](docs/API.md)
- [Development](docs/DEVELOPMENT.md)
- [Roadmap](docs/ROADMAP.md)

## License

MIT. See [LICENSE](LICENSE).
