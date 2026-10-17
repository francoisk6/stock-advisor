"""Headlines from Google News RSS (free, no key, dated and attributed).

Dev/prototype source like yfinance: check the terms (or switch to a licensed news API) before
launch — see CLAUDE.md.
"""

import asyncio
import re
import time
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime

import httpx

from app.db.models import Asset
from app.market_data.types import ProviderError

FEED_URL = "https://news.google.com/rss/search"
MIN_INTERVAL_SECONDS = 2.0
RATE_LIMIT_COOLDOWN_SECONDS = 300

_SUFFIX = re.compile(
    r"[,\s]+(Inc\.?|Incorporated|Corporation|Corp\.?|Company|Co\.?|Ltd\.?|Limited|PLC|plc|"
    r"S\.A\.?|S\.A\.E\.?|SE|N\.V\.?|AG|PJSC|P\.J\.S\.C\.|Holdings?|Group|Class [A-C])$"
)


@dataclass
class NewsItem:
    title: str
    url: str
    source: str
    published_at: datetime  # naive UTC


def _strip_suffixes(name: str) -> str:
    previous = None
    while previous != name:
        previous, name = name, _SUFFIX.sub("", name).strip(" ,.")
    return name


def short_name(asset: Asset) -> str:
    """The name people search for: 'Saudi Aramco (Saudi Arabian Oil Company)' -> 'Saudi Aramco',
    'NVIDIA Corporation' -> 'NVIDIA'. Short acronyms are ambiguous ('QNB' is also a US bank), so
    'QNB (Qatar National Bank)' -> 'Qatar National Bank'."""
    outside, _, inside = asset.name.partition("(")
    name = _strip_suffixes(outside.strip()) or asset.name
    full = _strip_suffixes(inside.rstrip(") ").strip())
    if len(name) <= 4 and full:
        return full
    return name or asset.symbol


def news_query(asset: Asset) -> str:
    name = short_name(asset)
    query = {
        "crypto": f'"{name}" crypto',
        "forex": f'"{asset.symbol}" exchange rate',
        "commodity": f'"{name}" price',
        "index": f'"{name}"',
    }.get(asset.asset_type, f'"{name}" stock')
    return f"{query} when:7d"


def parse_feed(xml_text: str) -> list[NewsItem]:
    items = []
    for node in ET.fromstring(xml_text).findall("./channel/item"):
        title = (node.findtext("title") or "").strip()
        url = (node.findtext("link") or "").strip()
        source = (node.findtext("source") or "").strip() or "Google News"
        published = node.findtext("pubDate")
        if not title or not url or not published:
            continue
        # Titles end with " - <Source>"; the source is shown separately.
        if title.endswith(f" - {source}"):
            title = title[: -len(source) - 3].rstrip()
        try:
            when = parsedate_to_datetime(published).astimezone(timezone.utc).replace(tzinfo=None)
        except (TypeError, ValueError):
            continue
        items.append(NewsItem(title[:500], url, source[:120], when.replace(microsecond=0)))
    return items


class GoogleNews:
    name = "google_news"

    def __init__(self) -> None:
        self._lock = asyncio.Lock()
        self._last_call = 0.0
        self._cooldown_until = 0.0

    async def search(self, query: str) -> list[NewsItem]:
        if time.monotonic() < self._cooldown_until:
            raise ProviderError("Google News is rate limiting (cooling down)")
        async with self._lock:
            wait = MIN_INTERVAL_SECONDS - (time.monotonic() - self._last_call)
            if wait > 0:
                await asyncio.sleep(wait)
            try:
                async with httpx.AsyncClient(timeout=20, follow_redirects=True) as client:
                    response = await client.get(
                        FEED_URL,
                        params={"q": query, "hl": "en-US", "gl": "US", "ceid": "US:en"},
                    )
            except httpx.HTTPError as exc:
                raise ProviderError(f"Google News unreachable: {exc}") from exc
            finally:
                self._last_call = time.monotonic()
        if response.status_code in (429, 503):
            self._cooldown_until = time.monotonic() + RATE_LIMIT_COOLDOWN_SECONDS
            raise ProviderError("Google News rate limit reached")
        if response.status_code >= 400:
            raise ProviderError(f"Google News error {response.status_code}")
        try:
            return parse_feed(response.text)
        except ET.ParseError as exc:
            raise ProviderError("Google News sent an unreadable feed") from exc
