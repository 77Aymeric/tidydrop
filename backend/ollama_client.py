from __future__ import annotations

import json
import re
from typing import Any

import httpx

from backend.config import OLLAMA_BASE_URL
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
        return await self._generate(model, build_text_prompt(file, categories, settings))

    async def classify_image(
        self, file: FileItem, categories: list[Category], settings: ClassificationSettings
    ) -> dict[str, Any]:
        model = settings.vision_model or settings.model
        if not model:
            raise OllamaUnavailable("No vision model selected.")
        return await self._generate(model, build_image_prompt(file, categories, settings), [file.image_b64] if file.image_b64 else [])

    async def _generate(self, model: str, prompt: str, images: list[str] | None = None) -> dict[str, Any]:
        payload: dict[str, Any] = {
            "model": model,
            "prompt": prompt,
            "stream": False,
            "format": "json",
            "options": {"temperature": 0.1},
        }
        if images:
            payload["images"] = images
        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.post(f"{self.base_url}/api/generate", json=payload)
            response.raise_for_status()
        except httpx.HTTPError as exc:
            raise OllamaUnavailable("Ollama is not running. Start it with: ollama serve") from exc
        return parse_model_json(response.json().get("response", ""))


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

Return valid JSON only:
{{
  "category_id": "...",
  "confidence": 0.0,
  "reason": "short reason",
  "suggested_filename": "optional_new_filename.ext",
  "needs_review": true
}}"""
