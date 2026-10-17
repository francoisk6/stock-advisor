from dataclasses import dataclass, field
from typing import Any, Literal


@dataclass
class ToolCall:
    name: str
    arguments: dict[str, Any]


@dataclass
class ChatMessage:
    """One message in the model's conversation (OpenAI/Ollama style roles)."""

    role: Literal["system", "user", "assistant", "tool"]
    content: str = ""
    tool_calls: list[ToolCall] = field(default_factory=list)
    tool_name: str | None = None  # for role="tool"


@dataclass
class ToolSpec:
    name: str
    description: str
    parameters: dict[str, Any]  # JSON schema


# What a provider streams back for one model call.
@dataclass
class TextDelta:
    text: str


@dataclass
class ToolCalls:
    calls: list[ToolCall]


@dataclass
class Finished:
    prompt_tokens: int = 0
    output_tokens: int = 0
    seconds: float = 0.0


ProviderEvent = TextDelta | ToolCalls | Finished


class AIUnavailable(Exception):
    """The model server is down, overloaded or answered with an error."""
