"""Built-in glossary: vetted plain-language explanations of investing terms.

Content lives in `glossary_<lang>.json` (data, not code) so the app's glossary screen, the
"Explain this" sheets and the copilot's `explain_term` tool all use the same wording.
"""

import json
import re
from functools import cache
from pathlib import Path

from pydantic import BaseModel

CATEGORIES = (
    "basics",
    "valuation",
    "funds",
    "crypto",
    "risk",
    "portfolio",
    "trading",
    "charts",
    "economy",
)
DEFAULT_LANG = "en"


class Term(BaseModel):
    id: str
    term: str
    aliases: list[str] = []
    category: str
    short: str
    body: str
    example: str | None = None
    related: list[str] = []


def _normalize(text: str) -> str:
    text = text.lower().replace("’", "'").replace("–", "-")
    text = re.sub(r"\([^)]*\)", " ", text)  # "ETF (exchange-traded fund)" -> "etf"
    text = re.sub(r"[^a-z0-9&/%+]+", " ", text)
    return " ".join(text.split())


_DIR = Path(__file__).parent
LANGS = frozenset(p.stem.removeprefix("glossary_") for p in _DIR.glob("glossary_*.json"))


def _lang(lang: str) -> str:
    # Only languages we ship: the value comes from a query string and names a file.
    return lang if lang in LANGS else DEFAULT_LANG


def terms(lang: str = DEFAULT_LANG) -> tuple[Term, ...]:
    return _load(_lang(lang))


@cache
def _load(lang: str) -> tuple[Term, ...]:
    path = _DIR / f"glossary_{lang}.json"
    loaded = tuple(Term(**t) for t in json.loads(path.read_text(encoding="utf-8")))
    return tuple(sorted(loaded, key=lambda t: t.term.lower()))


@cache
def _index(lang: str) -> dict[str, Term]:
    index: dict[str, Term] = {}
    for t in _load(lang):
        for name in (t.id.replace("-", " "), t.term, *t.aliases):
            index.setdefault(_normalize(name), t)
    return index


def get(term_id: str, lang: str = DEFAULT_LANG) -> Term | None:
    return next((t for t in terms(lang) if t.id == term_id), None)


def find(query: str, lang: str = DEFAULT_LANG) -> Term | None:
    """Best match for a name the user (or the model) typed: id, term or alias; then a known
    name inside the query ("what does P/E mean" -> P/E ratio), longest name first."""
    q = _normalize(query)
    if not q:
        return None
    index = _index(_lang(lang))
    if q in index:
        return index[q]
    if q.endswith("s") and q[:-1] in index:
        return index[q[:-1]]
    padded = f" {q} "
    # "exchange rates" should find "exchange rate", not the shorter "exchange".
    singular = " " + " ".join(w[:-1] if len(w) > 3 and w.endswith("s") else w for w in q.split())
    singular += " "
    for name in sorted(index, key=len, reverse=True):
        if len(name) >= 2 and (f" {name} " in padded or f" {name} " in singular):
            return index[name]
    return None
