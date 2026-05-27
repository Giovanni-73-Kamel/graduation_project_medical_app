from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Any, Dict

from app.config import settings
from app.services.ai_prompts import CHAT_PROMPT_V1, CHAT_PROMPT_VERSION

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class ChatResponse:
    reply: str
    model: str
    prompt_version: str


class MedicalChatService:
    def __init__(self) -> None:
        self.api_key = settings.gemini_api_key.strip()
        self.model_name = settings.gemini_model_name.strip()
        self.timeout_seconds = settings.gemini_request_timeout_seconds
        self.max_output_tokens = settings.gemini_max_output_tokens

    def ask(self, message: str) -> ChatResponse:
        cleaned_message = (message or "").strip()
        if not cleaned_message:
            raise ValueError("message cannot be empty")
        if not self.api_key:
            raise RuntimeError("Gemini API key is not configured")
        if not self.model_name:
            raise RuntimeError("Gemini model name is not configured")

        try:
            import google.generativeai as genai  # type: ignore
        except Exception as exc:  # pragma: no cover - optional dependency
            raise RuntimeError(f"Gemini client is unavailable: {exc}") from exc

        genai.configure(api_key=self.api_key)
        model = genai.GenerativeModel(self.model_name)
        prompt = f"{CHAT_PROMPT_V1}\nUser message:\n{cleaned_message}"

        logger.info("Submitting chat request to %s", self.model_name)
        response = model.generate_content(
            prompt,
            generation_config={
                "temperature": 0.2,
                "max_output_tokens": self.max_output_tokens,
            },
            request_options={"timeout": self.timeout_seconds},
        )
        reply = getattr(response, "text", "") or "Sorry, I could not generate a reply."
        return ChatResponse(
            reply=reply.strip(),
            model=self.model_name,
            prompt_version=CHAT_PROMPT_VERSION,
        )


_chat_service: MedicalChatService | None = None


def get_chat_service() -> MedicalChatService:
    global _chat_service
    if _chat_service is None:
        _chat_service = MedicalChatService()
    return _chat_service
