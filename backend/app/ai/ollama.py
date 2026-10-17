"""Ollama `/api/chat` with streaming and tool calling."""

import json
from collections.abc import AsyncIterator
from typing import Any

import httpx

from app.ai.types import (
    AIUnavailable,
    ChatMessage,
    Finished,
    ProviderEvent,
    TextDelta,
    ToolCall,
    ToolCalls,
    ToolSpec,
)
from app.core.config import settings


def to_ollama(message: ChatMessage) -> dict[str, Any]:
    out: dict[str, Any] = {"role": message.role, "content": message.content}
    if message.tool_calls:
        out["tool_calls"] = [
            {"function": {"name": c.name, "arguments": c.arguments}} for c in message.tool_calls
        ]
    if message.tool_name:
        out["tool_name"] = message.tool_name
    return out


def parse_tool_calls(raw: list[dict[str, Any]] | None) -> list[ToolCall]:
    calls = []
    for item in raw or []:
        function = item.get("function") or {}
        arguments = function.get("arguments") or {}
        if isinstance(arguments, str):  # some models send a JSON string
            try:
                arguments = json.loads(arguments)
            except ValueError:
                arguments = {}
        if function.get("name"):
            calls.append(ToolCall(name=function["name"], arguments=dict(arguments)))
    return calls


class OllamaProvider:
    name = "ollama"

    def __init__(
        self,
        base_url: str | None = None,
        model: str | None = None,
        transport: httpx.AsyncBaseTransport | None = None,  # tests
    ) -> None:
        self.base_url = base_url or settings.ollama_url
        self.model = model or settings.ollama_model
        self._transport = transport

    async def stream_chat(
        self, messages: list[ChatMessage], tools: list[ToolSpec]
    ) -> AsyncIterator[ProviderEvent]:
        payload = {
            "model": self.model,
            "messages": [to_ollama(m) for m in messages],
            "tools": [
                {
                    "type": "function",
                    "function": {
                        "name": t.name,
                        "description": t.description,
                        "parameters": t.parameters,
                    },
                }
                for t in tools
            ],
            "stream": True,
            "think": settings.ai_think,
            "options": {
                "num_thread": settings.ollama_num_thread,
                "num_ctx": settings.ollama_num_ctx,
                "temperature": 0.3,
            },
        }
        timeout = httpx.Timeout(settings.ollama_timeout_seconds, connect=5)
        calls: list[ToolCall] = []
        try:
            async with (
                httpx.AsyncClient(
                    base_url=self.base_url, timeout=timeout, transport=self._transport
                ) as client,
                client.stream("POST", "/api/chat", json=payload) as response,
            ):
                if response.status_code >= 400:
                    body = (await response.aread()).decode(errors="replace")[:300]
                    raise AIUnavailable(f"Ollama error {response.status_code}: {body}")
                async for line in response.aiter_lines():
                    if not line.strip():
                        continue
                    chunk = json.loads(line)
                    if chunk.get("error"):
                        raise AIUnavailable(str(chunk["error"]))
                    message = chunk.get("message") or {}
                    if message.get("content"):
                        yield TextDelta(message["content"])
                    calls.extend(parse_tool_calls(message.get("tool_calls")))
                    if chunk.get("done"):
                        if calls:
                            yield ToolCalls(calls)
                        yield Finished(
                            prompt_tokens=chunk.get("prompt_eval_count", 0),
                            output_tokens=chunk.get("eval_count", 0),
                            seconds=chunk.get("total_duration", 0) / 1e9,
                        )
                        return
        except httpx.HTTPError as exc:
            raise AIUnavailable(f"Ollama unreachable: {exc}") from exc
