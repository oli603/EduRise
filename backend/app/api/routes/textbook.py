from typing import Optional
from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel
from ...core.security import get_current_user, AuthenticatedUser
from ...core.rate_limit import check_rate_limit
from ...core.idempotency import IdempotencyManager
from ...services.textbook_service import TextbookService

router = APIRouter(prefix="/textbook", tags=["Textbook Educational Tools"])
textbook_service = TextbookService()


class TextbookToolRequest(BaseModel):
    unit_id: str
    grade: str
    subject: str
    unit_number: int = 1
    unit_name: Optional[str] = None
    unit_title: Optional[str] = None
    book_id: Optional[str] = None
    textbook_context: str = ""
    unit_content: Optional[str] = None
    specific_concept: Optional[str] = None
    version: str = "1"


def _resolve_unit_name(req: TextbookToolRequest) -> str:
    if req.unit_name and req.unit_name.strip():
        return req.unit_name.strip()
    if req.unit_title and req.unit_title.strip():
        return req.unit_title.strip()
    return f"Unit {req.unit_number}"


def _resolve_context(req: TextbookToolRequest) -> str:
    if req.textbook_context and req.textbook_context.strip():
        return req.textbook_context.strip()
    if req.unit_content and req.unit_content.strip():
        return req.unit_content.strip()
    return ""


def check_stream_access(user: AuthenticatedUser, grade: str, subject: str) -> None:
    """
    Enforces stream isolation for upper secondary (Grades 11 & 12).
    Natural students cannot access Social-only subjects (History, Geography, Economics).
    Social students cannot access Natural-only subjects (Physics, Chemistry, Biology).
    Grades 9 & 10 are common foundational curriculum and accessible to all students.
    """
    grade_clean = grade.lower().replace("grade", "").strip()
    if grade_clean in ["9", "10"]:
        return

    sub = subject.lower().strip()
    user_stream = (user.stream or "natural").lower().strip()

    natural_only_subjects = ["physics", "chemistry", "biology"]
    social_only_subjects = ["history", "geography", "economics"]

    if user_stream == "natural" and sub in social_only_subjects:
        raise HTTPException(
            status_code=403,
            detail=f"Access denied. Natural Science students cannot access Social Science subject: {subject} in Grade {grade}.",
        )
    if user_stream == "social" and sub in natural_only_subjects:
        raise HTTPException(
            status_code=403,
            detail=f"Access denied. Social Science students cannot access Natural Science subject: {subject} in Grade {grade}.",
        )


@router.post("/summary")
async def get_unit_summary(
    req: TextbookToolRequest,
    user: AuthenticatedUser = Depends(get_current_user),
    idempotency_key: Optional[str] = Header(None, alias="Idempotency-Key"),
):
    check_stream_access(user, req.grade, req.subject)
    check_rate_limit(f"summary:{user.uid}")
    if idempotency_key:
        cached = IdempotencyManager.get(idempotency_key)
        if cached and cached["status"] == "completed":
            return cached["result"]
        IdempotencyManager.start(idempotency_key)

    unit_name = _resolve_unit_name(req)
    context = _resolve_context(req)

    res = await textbook_service.get_summary(
        unit_id=req.unit_id,
        grade=req.grade,
        subject=req.subject,
        unit_number=req.unit_number,
        unit_name=unit_name,
        textbook_context=context,
        version=req.version,
    )
    if idempotency_key:
        IdempotencyManager.complete(idempotency_key, res)
    return res


@router.post("/flashcards")
async def get_unit_flashcards(
    req: TextbookToolRequest,
    user: AuthenticatedUser = Depends(get_current_user),
    idempotency_key: Optional[str] = Header(None, alias="Idempotency-Key"),
):
    check_stream_access(user, req.grade, req.subject)
    check_rate_limit(f"flashcards:{user.uid}")
    if idempotency_key:
        cached = IdempotencyManager.get(idempotency_key)
        if cached and cached["status"] == "completed":
            return cached["result"]
        IdempotencyManager.start(idempotency_key)

    unit_name = _resolve_unit_name(req)
    context = _resolve_context(req)

    res = await textbook_service.get_flashcards(
        unit_id=req.unit_id,
        grade=req.grade,
        subject=req.subject,
        unit_number=req.unit_number,
        unit_name=unit_name,
        textbook_context=context,
        version=req.version,
    )
    if idempotency_key:
        IdempotencyManager.complete(idempotency_key, res)
    return res


@router.post("/ai-notes")
@router.post("/notes")
async def get_unit_ai_notes(
    req: TextbookToolRequest,
    user: AuthenticatedUser = Depends(get_current_user),
    idempotency_key: Optional[str] = Header(None, alias="Idempotency-Key"),
):
    check_stream_access(user, req.grade, req.subject)
    check_rate_limit(f"ai_notes:{user.uid}")
    if idempotency_key:
        cached = IdempotencyManager.get(idempotency_key)
        if cached and cached["status"] == "completed":
            return cached["result"]
        IdempotencyManager.start(idempotency_key)

    unit_name = _resolve_unit_name(req)
    context = _resolve_context(req)

    res = await textbook_service.get_ai_notes(
        unit_id=req.unit_id,
        grade=req.grade,
        subject=req.subject,
        unit_number=req.unit_number,
        unit_name=unit_name,
        textbook_context=context,
        version=req.version,
    )
    if idempotency_key:
        IdempotencyManager.complete(idempotency_key, res)
    return res


@router.post("/understand-unit")
async def get_understand_unit(
    req: TextbookToolRequest,
    user: AuthenticatedUser = Depends(get_current_user),
    idempotency_key: Optional[str] = Header(None, alias="Idempotency-Key"),
):
    check_stream_access(user, req.grade, req.subject)
    check_rate_limit(f"understand_unit:{user.uid}")
    if idempotency_key:
        cached = IdempotencyManager.get(idempotency_key)
        if cached and cached["status"] == "completed":
            return cached["result"]
        IdempotencyManager.start(idempotency_key)

    unit_name = _resolve_unit_name(req)
    context = _resolve_context(req)

    res = await textbook_service.get_understand_unit(
        unit_id=req.unit_id,
        grade=req.grade,
        subject=req.subject,
        unit_number=req.unit_number,
        unit_name=unit_name,
        textbook_context=context,
        version=req.version,
    )
    if idempotency_key:
        IdempotencyManager.complete(idempotency_key, res)
    return res


@router.post("/quiz")
async def get_unit_quiz(
    req: TextbookToolRequest,
    user: AuthenticatedUser = Depends(get_current_user),
    idempotency_key: Optional[str] = Header(None, alias="Idempotency-Key"),
):
    check_stream_access(user, req.grade, req.subject)
    check_rate_limit(f"quiz:{user.uid}")
    if idempotency_key:
        cached = IdempotencyManager.get(idempotency_key)
        if cached and cached["status"] == "completed":
            return cached["result"]
        IdempotencyManager.start(idempotency_key)

    unit_name = _resolve_unit_name(req)
    context = _resolve_context(req)

    res = await textbook_service.get_quiz(
        unit_id=req.unit_id,
        grade=req.grade,
        subject=req.subject,
        unit_number=req.unit_number,
        unit_name=unit_name,
        textbook_context=context,
        version=req.version,
    )
    if idempotency_key:
        IdempotencyManager.complete(idempotency_key, res)
    return res
