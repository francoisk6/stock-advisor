from fastapi import APIRouter

from app.api.deps import CurrentUser
from app.core.errors import NotFoundError
from app.learn import glossary
from app.schemas.learn import TermOut

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
