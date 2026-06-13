# Model Strategy

TidyDrop is model-agnostic at the API boundary: it lists locally installed Ollama models and lets the user select each role. The defaults are selected by name when the recommended models are present.

## Recommended 16 GB Workflow

| Role | Model | Approximate disk use | Why |
| --- | --- | ---: | --- |
| Fast pass | `qwen3.5:2b` | 2.7 GB | Low latency across every file |
| Expert text | `qwen3.5:9b` | 6.6 GB | Better collection reasoning, naming, and uncertain-file review |
| Expert vision | `gemma4:e4b-it-qat` | 6.1 GB | Image understanding without a model above 9B |
| Total |  | about 15.4 GB | Models are not intended to remain loaded together |

Sizes are approximate Ollama artifact sizes and can change with model revisions. TidyDrop never pulls models automatically.

```bash
ollama pull qwen3.5:2b
ollama pull qwen3.5:9b
ollama pull gemma4:e4b-it-qat
```

## Why Multiple Models

Running the strongest model on every file is slow and can produce large memory spikes. TidyDrop instead uses:

1. one expert collection pass to discover useful folders;
2. one small fast pass across all files;
3. selective expert review for uncertain results;
4. a vision expert only for images that need it.

Each phase is sequential. The app requests an Ollama unload between model phases, while Ollama generation uses a short `keep_alive`.

## Lower-Storage Configuration

Use one capable text model for both fast and expert roles, and leave the vision role empty if image understanding is not required. This reduces storage at the cost of speed or image quality.

The app still scans images as metadata-only items and can classify them from filename/path clues with the selected text model.

## Selection Guidance

Choose models that reliably support Ollama structured JSON output. The task needs:

- instruction following;
- concise classification;
- semantic clustering;
- calibrated confidence;
- filenames that preserve the original extension;
- vision support only for the vision role.

Raw benchmark intelligence is not the only factor. A smaller model that consistently returns the required schema can be more useful than a larger model that times out or emits malformed output.

## Runtime Options

Classification requests use:

```json
{
  "stream": false,
  "think": false,
  "format": "<JSON schema>",
  "keep_alive": "2m",
  "options": {
    "temperature": 0,
    "num_ctx": 4096,
    "num_predict": 256
  }
}
```

Folder discovery increases the context to `8192` and output budget to `1024`.
