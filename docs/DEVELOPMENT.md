# Development

## Local Setup

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -e ".[dev]"
swift build
```

## Run

```bash
./script/build_and_run.sh
```

Useful variants:

```bash
./script/build_and_run.sh --verify
./script/build_and_run.sh --logs
./script/build_and_run.sh --debug
```

## Checks

```bash
swift build
python -m pytest
python -m ruff check backend tests
```

## Ollama

Classification requires local Ollama:

```bash
ollama serve
ollama pull llama3.1
```

Vision classification requires a vision-capable model, for example:

```bash
ollama pull llama3.2-vision
```

## Repository Layout

```text
Sources/TidyDrop/   Native macOS SwiftUI app
backend/            Local FastAPI engine
tests/              Backend tests
script/             Build and run scripts
docs/               Project documentation
```
