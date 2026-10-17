"""General web search through our own SearXNG instance (free, no key, local only)."""

from dataclasses import dataclass

import httpx

from app.core.config import settings
from app.market_data.types import ProviderError


@dataclass
class WebResult:
    title: str
    url: str
    snippet: str


async def search(query: str, limit: int = 5) -> list[WebResult]:
    try:
        async with httpx.AsyncClient(base_url=settings.searxng_url, timeout=15) as client:
            response = await client.get(
                "/search", params={"q": query, "format": "json", "safesearch": 1}
            )
    except httpx.HTTPError as exc:
        raise ProviderError(f"Web search unreachable: {exc}") from exc
    if response.status_code >= 400:
        raise ProviderError(f"Web search error {response.status_code}")
    results, seen = [], set()
    for item in response.json().get("results", []):
        url = item.get("url")
        if not url or url in seen:
            continue
        seen.add(url)
        results.append(
            WebResult(
                title=(item.get("title") or url)[:200],
                url=url,
                snippet=" ".join((item.get("content") or "").split())[:300],
            )
        )
        if len(results) >= limit:
            break
    return results
