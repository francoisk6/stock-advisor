from pydantic import BaseModel


class TermOut(BaseModel):
    id: str
    term: str
    aliases: list[str]
    category: str
    short: str
    body: str
    example: str | None
    related: list[str]


class LessonSummaryOut(BaseModel):
    id: str
    title: str
    minutes: int
    level: str
    summary: str
    suggested: bool
    done: bool
    best_score: int | None
    total: int


class SectionOut(BaseModel):
    heading: str
    body: str


class QuestionOut(BaseModel):
    question: str
    options: list[str]  # the answer is only revealed after submitting


class LessonOut(LessonSummaryOut):
    sections: list[SectionOut]
    terms: list[str]
    quiz: list[QuestionOut]


class QuizIn(BaseModel):
    answers: list[int]


class AnswerResultOut(BaseModel):
    correct: bool
    answer: int
    explanation: str


class QuizResultOut(BaseModel):
    score: int
    total: int
    best_score: int
    results: list[AnswerResultOut]
