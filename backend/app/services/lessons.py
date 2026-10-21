"""Lesson progress: quiz results per user. Lesson content comes from app/learn/lessons.py."""

from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError, NotFoundError
from app.core.time import utcnow
from app.db.models import LessonProgress, User
from app.learn import lessons as content


@dataclass
class QuizResult:
    lesson: content.Lesson
    answers: list[int]
    progress: LessonProgress

    @property
    def score(self) -> int:
        return sum(a == q.answer for a, q in zip(self.answers, self.lesson.quiz, strict=True))


def get_lesson(lesson_id: str) -> content.Lesson:
    lesson = content.get(lesson_id)
    if lesson is None:
        raise NotFoundError("We don't have that lesson.")
    return lesson


async def progress_for(session: AsyncSession, user: User) -> dict[str, LessonProgress]:
    rows = await session.execute(select(LessonProgress).where(LessonProgress.user_id == user.id))
    return {p.lesson_id: p for p in rows.scalars()}


def suggested_ids(user: User, done: set[str]) -> list[str]:
    profile = user.profile
    interests = list(profile.asset_interests or []) if profile else []
    level = profile.experience_level if profile else None
    return [x.id for x in content.suggested(interests, level, done)]


async def submit_quiz(
    session: AsyncSession, user: User, lesson_id: str, answers: list[int]
) -> QuizResult:
    lesson = get_lesson(lesson_id)
    if len(answers) != len(lesson.quiz):
        raise AppError(f"Please answer all {len(lesson.quiz)} questions.")
    progress = (await progress_for(session, user)).get(lesson_id)
    if progress is None:
        progress = LessonProgress(
            user_id=user.id, lesson_id=lesson_id, total=len(lesson.quiz), completed_at=utcnow()
        )
        session.add(progress)
    result = QuizResult(lesson, answers, progress)
    progress.attempts = (progress.attempts or 0) + 1
    progress.last_score = result.score
    progress.best_score = max(progress.best_score or 0, result.score)
    progress.total = len(lesson.quiz)
    progress.completed_at = utcnow()
    await session.commit()
    return result
