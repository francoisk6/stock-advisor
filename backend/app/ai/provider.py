from collections.abc import AsyncIterator
from typing import Protocol

from app.ai.types import ChatMessage, ProviderEvent, ToolSpec


class LLMProvider(Protocol):
    """A chat model with tool calling. Swappable: Ollama now, a GPU server or hosted API later."""

    name: str

    def stream_chat(
        self, messages: list[ChatMessage], tools: list[ToolSpec]
    ) -> AsyncIterator[ProviderEvent]: ...
