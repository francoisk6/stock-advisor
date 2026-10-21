from fastapi import APIRouter

from app.api.deps import CurrentUser, SessionDep
from app.core.errors import NotFoundError
from app.db.models import LessonProgress
from app.learn import glossary
from app.learn.lessons import Lesson
from app.schemas.learn import (
    AnswerResultOut,
    LessonOut,
    LessonSummaryOut,
    QuestionOut,
    QuizIn,
    QuizResultOut,
    SectionOut,
    TermOut,
)
from app.services import lessons as lessons_service

router = APIRouter(prefix="/learn", tags=["learn"])


@router.get("/glossary", response_model=list[TermOut])
async def list_terms(_: CurrentUser, lang: str = glossary.DEFAULT_LANG) -> list[glossary.Term]:
    return list(glossary.terms(lang))


@router.get("/glossary/{term_id}", response_model=TermOut)
async def get_term(
    term_id: str, _: CurrentUser, lang: str = glossary.DEFAULT_LANG
) -> glossary.Term:
    term = glossary.get(term_id, lang)
    if term is None:
        raise NotFoundError("We don't have that term in the glossary yet.")
    return term


def _summary(lesson: Lesson, progress: LessonProgress | None, suggested: bool) -> dict:
    return {
        "id": lesson.id,
        "title": lesson.title,
        "minutes": lesson.minutes,
        "level": lesson.level,
        "summary": lesson.summary,
        "suggested": suggested,
        "done": progress is not None,
        "best_score": progress.best_score if progress else None,
        "total": len(lesson.quiz),
    }


@router.get("/lessons", response_model=list[LessonSummaryOut])
async def list_lessons(session: SessionDep, user: CurrentUser) -> list[LessonSummaryOut]:
    """Suggested lessons first (fitting the user's interests and level), then the rest."""
    progress = await lessons_service.progress_for(session, user)
    suggested = lessons_service.suggested_ids(user, set(progress))
    all_lessons = lessons_service.content.lessons()
    ordered = sorted(all_lessons, key=lambda x: (x.id not in suggested, x.id in progress))
    return [LessonSummaryOut(**_summary(x, progress.get(x.id), x.id in suggested)) for x in ordered]


@router.get("/lessons/{lesson_id}", response_model=LessonOut)
async def get_lesson(lesson_id: str, session: SessionDep, user: CurrentUser) -> LessonOut:
    lesson = lessons_service.get_lesson(lesson_id)
    progress = (await lessons_service.progress_for(session, user)).get(lesson_id)
    return LessonOut(
        **_summary(lesson, progress, False),
        sections=[SectionOut(heading=s.heading, body=s.body) for s in lesson.sections],
        terms=lesson.terms,
        quiz=[QuestionOut(question=q.question, options=q.options) for q in lesson.quiz],
    )


@router.post("/lessons/{lesson_id}/quiz", response_model=QuizResultOut)
async def submit_quiz(
    lesson_id: str, body: QuizIn, session: SessionDep, user: CurrentUser
) -> QuizResultOut:
    result = await lessons_service.submit_quiz(session, user, lesson_id, body.answers)
    return QuizResultOut(
        score=result.score,
        total=len(result.lesson.quiz),
        best_score=result.progress.best_score,
        results=[
            AnswerResultOut(correct=a == q.answer, answer=q.answer, explanation=q.explanation)
            for a, q in zip(result.answers, result.lesson.quiz, strict=True)
        ],
    )
