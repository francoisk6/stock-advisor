"""Short lessons with a 3-question quiz each. Content lives in `lessons_<lang>.json` (written
and reviewed by people; nothing is generated at runtime), in the order they're suggested."""

import json
from functools import cache
from pathlib import Path

from pydantic import BaseModel

from app.learn import glossary

_DIR = Path(__file__).parent
LANGS = frozenset(p.stem.removeprefix("lessons_") for p in _DIR.glob("lessons_*.json"))


class Section(BaseModel):
    heading: str
    body: str


class Question(BaseModel):
    question: str
    options: list[str]
    answer: int
    explanation: str


class Lesson(BaseModel):
    id: str
    title: str
    minutes: int
    level: str  # beginner | intermediate
    topics: list[str]  # onboarding interests (stocks, crypto, etfs, …) or "all"
    summary: str
    sections: list[Section]
    terms: list[str]  # glossary ids
    quiz: list[Question]


def _lang(lang: str) -> str:
    return lang if lang in LANGS else glossary.DEFAULT_LANG


@cache
def _load(lang: str) -> tuple[Lesson, ...]:
    path = _DIR / f"lessons_{lang}.json"
    return tuple(Lesson(**item) for item in json.loads(path.read_text(encoding="utf-8")))


def lessons(lang: str = glossary.DEFAULT_LANG) -> tuple[Lesson, ...]:
    return _load(_lang(lang))


def get(lesson_id: str, lang: str = glossary.DEFAULT_LANG) -> Lesson | None:
    return next((x for x in lessons(lang) if x.id == lesson_id), None)


def suggested(
    interests: list[str], level: str | None, done: set[str], lang: str = glossary.DEFAULT_LANG
) -> list[Lesson]:
    """Not-yet-finished lessons that fit the user's interests and level, in course order."""
    beginner = level in (None, "beginner")

    def fits(x: Lesson) -> bool:
        if beginner and x.level != "beginner":
            return False
        return "all" in x.topics or bool(set(x.topics) & set(interests))

    return [x for x in lessons(lang) if x.id not in done and fits(x)]


def find(topic: str, lang: str = glossary.DEFAULT_LANG) -> Lesson | None:
    """The lesson that best covers a topic: one that teaches the glossary term the topic names,
    else the one whose title and summary share the most words with it."""
    term = glossary.find(topic, lang)
    if term is not None:
        for x in lessons(lang):
            if term.id in x.terms:
                return x

    def stems(text: str) -> set[str]:
        return {w.strip(".,?!'\"").rstrip("s") for w in text.lower().split() if len(w) > 3}

    words = stems(topic)
    scored = [(len(words & stems(f"{x.title} {x.summary}")), x) for x in lessons(lang)]
    score, best = max(scored, key=lambda pair: pair[0])
    return best if score else None
