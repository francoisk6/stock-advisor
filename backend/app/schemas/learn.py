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
