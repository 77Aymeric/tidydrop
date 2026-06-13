from __future__ import annotations

import base64
import json
import os
import re
from pathlib import Path
from typing import Any

import httpx

from backend.config import MAX_IMAGE_BYTES, OLLAMA_BASE_URL
from backend.models import Category, ClassificationSettings, FileItem


class OllamaUnavailable(RuntimeError):
    pass


class OllamaClient:
    def __init__(self, base_url: str = OLLAMA_BASE_URL, timeout: float = 120) -> None:
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout

    async def health(self) -> bool:
        try:
            async with httpx.AsyncClient(timeout=3) as client:
                response = await client.get(f"{self.base_url}/api/tags")
            return response.status_code == 200
        except httpx.HTTPError:
            return False

    async def models(self) -> list[str]:
        try:
            async with httpx.AsyncClient(timeout=5) as client:
                response = await client.get(f"{self.base_url}/api/tags")
            response.raise_for_status()
            data = response.json()
            return [model.get("name", "") for model in data.get("models", []) if model.get("name")]
        except httpx.HTTPError as exc:
            raise OllamaUnavailable("Ollama is not running. Start it with: ollama serve") from exc

    async def classify_text(
        self, file: FileItem, categories: list[Category], settings: ClassificationSettings
    ) -> dict[str, Any]:
        model = settings.text_model or settings.model
        if not model:
            raise OllamaUnavailable("No text model selected.")
        return await self._generate(
            model,
            build_text_prompt(file, categories, settings),
            schema=CLASSIFICATION_SCHEMA,
            timeout=settings.ai_timeout_seconds,
        )

    async def classify_image(
        self, file: FileItem, categories: list[Category], settings: ClassificationSettings
    ) -> dict[str, Any]:
        model = settings.vision_model or settings.model
        if not model:
            raise OllamaUnavailable("No vision model selected.")
        return await self._generate(
            model,
            build_image_prompt(file, categories, settings),
            [_load_image_b64(file)],
            schema=CLASSIFICATION_SCHEMA,
            timeout=settings.ai_timeout_seconds,
        )

    async def discover_categories(
        self, files: list[FileItem], categories: list[Category], settings: ClassificationSettings
    ) -> dict[str, Any]:
        model = settings.text_model or settings.model
        if not model:
            raise OllamaUnavailable("No text model selected.")
        return await self._generate(
            model,
            build_category_discovery_prompt(files, categories, settings),
            schema=CATEGORY_DISCOVERY_SCHEMA,
            timeout=settings.ai_timeout_seconds,
            num_ctx=8192,
            num_predict=1024,
        )

    async def _generate(
        self,
        model: str,
        prompt: str,
        images: list[str] | None = None,
        schema: dict[str, Any] | None = None,
        timeout: float | None = None,
        num_ctx: int = 4096,
        num_predict: int = 256,
    ) -> dict[str, Any]:
        payload: dict[str, Any] = {
            "model": model,
            "prompt": prompt,
            "stream": False,
            "format": schema or "json",
            "think": False,
            "keep_alive": "2m",
            "options": {
                "temperature": 0,
                "num_ctx": num_ctx,
                "num_predict": num_predict,
            },
        }
        if images:
            payload["images"] = images
        try:
            async with httpx.AsyncClient(timeout=timeout or self.timeout) as client:
                response = await client.post(f"{self.base_url}/api/generate", json=payload)
            response.raise_for_status()
        except httpx.TimeoutException as exc:
            raise OllamaUnavailable("Ollama took too long. Increase the AI timeout or try a smaller folder.") from exc
        except httpx.HTTPError as exc:
            raise OllamaUnavailable("Ollama is not running. Start it with: ollama serve") from exc
        data = response.json()
        text = data.get("response", "")
        if data.get("done_reason") == "length":
            raise ValueError("Model output was truncated before producing JSON.")
        return parse_model_json(text)


CLASSIFICATION_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "category_id": {"type": "string"},
        "confidence": {"type": "number", "minimum": 0, "maximum": 1},
        "reason": {"type": "string"},
        "suggested_filename": {"type": ["string", "null"]},
        "needs_review": {"type": "boolean"},
    },
    "required": ["category_id", "confidence", "reason", "suggested_filename", "needs_review"],
    "additionalProperties": False,
}

CATEGORY_DISCOVERY_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "categories": {
            "type": "array",
            "minItems": 1,
            "maxItems": 5,
            "items": {
                "type": "object",
                "properties": {
                    "id": {"type": "string", "maxLength": 40},
                    "name": {"type": "string", "maxLength": 40},
                    "signals": {"type": "string", "maxLength": 60},
                },
                "required": ["id", "name", "signals"],
                "additionalProperties": False,
            },
        }
    },
    "required": ["categories"],
    "additionalProperties": False,
}


def _load_image_b64(file: FileItem) -> str:
    if file.image_b64:
        return file.image_b64
    path = Path(file.path)
    size = path.stat().st_size
    if size > MAX_IMAGE_BYTES:
        raise ValueError(f"Image exceeds the {MAX_IMAGE_BYTES // (1024 * 1024)} MB vision limit.")
    return base64.b64encode(path.read_bytes()).decode("ascii")


def parse_model_json(text: str) -> dict[str, Any]:
    try:
        parsed = json.loads(text)
        if isinstance(parsed, dict):
            return parsed
    except json.JSONDecodeError:
        pass
    match = re.search(r"\{.*\}", text, flags=re.DOTALL)
    if not match:
        raise ValueError("No JSON object found in model response.")
    parsed = json.loads(match.group(0))
    if not isinstance(parsed, dict):
        raise ValueError("Model response JSON is not an object.")
    return parsed


def _categories_json(categories: list[Category]) -> str:
    return json.dumps([category.model_dump() for category in categories], ensure_ascii=False, indent=2)


def build_text_prompt(file: FileItem, categories: list[Category], settings: ClassificationSettings) -> str:
    fallback = next((cat.name for cat in categories if cat.id == settings.fallback_category_id), settings.fallback_category_id)
    return f"""You are TidyDrop, a local AI file classification assistant.

You must classify the file into exactly one of the user-defined categories.
You must never invent categories.
Classify by semantic relationship: project, client, subject, event, workflow, and time period.
Prefer the most specific project or subject category over generic categories such as Documents, Code, or Media.
The file extension is supporting evidence only. Never choose a category primarily because of its extension.
Use shared names, entities, dates, paths, and content themes to connect this file with related files.
If the file is ambiguous, choose the fallback category.
You must return only valid JSON.

User categories:
{_categories_json(categories)}

File metadata:
- File name: {file.name}
- Extension: {file.extension}
- File kind: {file.file_kind}
- Size: {file.size}
- Path: {file.path}
- Last modified: {file.last_modified}

Available file understanding level:
{file.supported_level}

Metadata summary:
{file.metadata_summary}

Extracted content preview:
{file.content_preview}

Settings:
- Suggest renaming: {settings.suggest_renaming}
- Fallback category: {fallback}

When suggesting a filename:
- describe the content or project, not merely the file type;
- keep the original extension;
- include a useful date or project identifier when clearly supported;
- if the current name is generic, versioned, temporary, copied, or unclear, you MUST propose a better semantic name;
- names containing words such as copy, old, final, draft, temp, scan, export, doc, item, data, notes, or only numbers usually need improvement;
- return null only when the existing filename already identifies the subject or project clearly.

Confidence calibration:
- 0.95 or above requires explicit content evidence and a direct project/client/subject match;
- 0.75 to 0.94 means strong but incomplete semantic evidence;
- 0.50 to 0.74 means plausible and should usually be reviewed;
- extension or file type alone must never exceed 0.35;
- never return 1.0.

Return valid JSON only:
{{
  "category_id": "...",
  "confidence": 0.0,
  "reason": "short reason",
  "suggested_filename": "optional_new_filename.ext",
  "needs_review": true
}}"""


def build_image_prompt(file: FileItem, categories: list[Category], settings: ClassificationSettings) -> str:
    return f"""You are TidyDrop, a local AI file classification assistant.

Analyze the image and classify it into exactly one of the user-defined categories.
You must never invent categories.
Classify by the project, client, event, subject, or time period the image belongs to.
Prefer a specific semantic category over a generic Media or Images category.
Use visible text, logos, people, dates, visual style, and filename/path clues to connect it with related files.
If the image is blurry, unreadable, ambiguous, or does not clearly match a category, choose the fallback category.
If the user has a category for blurry images, use it when appropriate.
Return only valid JSON.

User categories:
{_categories_json(categories)}

Image metadata:
- File name: {file.name}
- Extension: {file.extension}
- Size: {file.size}
- Path: {file.path}

Instructions:
{settings.global_user_instructions}

When suggesting a filename:
- describe the visible subject or project, preserve the original extension, and use a supported date when useful;
- generic, camera-generated, copied, old, draft, or numbered names MUST receive a better proposal;
- return null only when the existing filename is already clear.

Confidence calibration:
- 0.95 or above requires explicit visible content or text matching a category;
- visual format alone must never exceed 0.35;
- never return 1.0.

Return valid JSON only:
{{
  "category_id": "...",
  "confidence": 0.0,
  "reason": "short reason",
  "suggested_filename": "optional_new_filename.ext",
  "needs_review": true
}}"""


def build_category_discovery_prompt(
    files: list[FileItem],
    categories: list[Category],
    settings: ClassificationSettings,
) -> str:
    paths = [Path(file.path) for file in files]
    common_root = Path(os.path.commonpath([path.parent for path in paths])) if paths else Path(".")

    sampled_files = [
        {
            "name": file.name,
            "path": _relative_display_path(Path(file.path), common_root),
            "kind": file.file_kind,
            "modified": file.last_modified[:10],
            "summary": file.metadata_summary[:120],
            "content": " ".join(file.content_preview[:220].split()),
        }
        for file in files[:200]
    ]
    return f"""You are TidyDrop, a local AI file organization assistant.

Your task is to study the whole scanned folder as a collection, infer which files belong together, and suggest useful semantic sorting folders.

Rules:
- Return only valid JSON.
- Do not remove existing user categories.
- Do not duplicate an existing category by meaning or name.
- Group primarily by shared project, client, organization, subject, event, workflow, or meaningful time period.
- Connect files using content, repeated names/entities, dates, neighboring paths, filename stems, and version/backup relationships.
- A project folder may contain mixed formats such as documents, code, images, data, and configuration files.
- Do not create categories based only on extensions or broad file kinds.
- Avoid generic categories such as Documents, Code, Images, Media, PDFs, Spreadsheets, or Archives when a semantic group can be inferred.
- Suggest only categories that help classify multiple related files or a clearly important standalone project.
- Return 3 to 5 strong, human-meaningful groups, never more than {settings.max_ai_categories}.
- Keep category names short, human-readable folder names.
- For each group, return only id, name, and signals.
- Signals must be a comma-separated list of 2 to 4 concrete names, topics, or date clues.
- Be extremely concise so the complete JSON fits in the response.
- Always keep the fallback category for uncertain files.
- Maximum new categories: {settings.max_ai_categories}

Existing user categories:
{_categories_json(categories)}

Scanned files sample:
{json.dumps(sampled_files, ensure_ascii=False, indent=2)}

Return valid JSON only:
{{
  "categories": [
    {{
      "id": "short-stable-kebab-id",
      "name": "Folder Name",
      "signals": "client name, project keyword, year"
    }}
  ]
}}"""


def _relative_display_path(path: Path, root: Path) -> str:
    try:
        return str(path.relative_to(root))
    except ValueError:
        return path.name
