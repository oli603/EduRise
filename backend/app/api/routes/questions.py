from typing import List, Optional
from fastapi import APIRouter, Depends, Header
from pydantic import BaseModel
from ...core.security import get_current_user, AuthenticatedUser
from ...core.rate_limit import check_rate_limit
from ...core.idempotency import IdempotencyManager
from ...services.question_service import QuestionService
from ...services.reporting_service import ReportingService

router = APIRouter(prefix="/questions", tags=["Questions & Explanations"])
question_service = QuestionService()


class ExplainMoreRequest(BaseModel):
    question_id: str
    question_text: str
    options: List[str]
    correct_answer: str
    existing_explanation: str = ""
    selected_answer: Optional[str] = None
    subject: Optional[str] = None
    grade: Optional[str] = None
    version: str = "1"


class ReportQuestionRequest(BaseModel):
    question_id: str
    question_text: str
    reason: str
    additional_feedback: Optional[str] = None
    subject: str = "General"
    grade: str = "Grade 12"
    unit_number: int = 1


@router.post("/explain")
async def explain_more(
    req: ExplainMoreRequest,
    user: AuthenticatedUser = Depends(get_current_user),
    idempotency_key: Optional[str] = Header(None, alias="Idempotency-Key"),
):
    check_rate_limit(f"explain:{user.uid}")

    if idempotency_key:
        cached = IdempotencyManager.get(idempotency_key)
        if cached and cached["status"] == "completed":
            return cached["result"]
        IdempotencyManager.start(idempotency_key)

    response = await question_service.get_deep_explanation(
        question_id=req.question_id,
        question_text=req.question_text,
        options=req.options,
        correct_answer=req.correct_answer,
        existing_explanation=req.existing_explanation,
        version=req.version,
        selected_answer=req.selected_answer,
        subject=req.subject,
        grade=req.grade,
    )

    if idempotency_key:
        IdempotencyManager.complete(idempotency_key, response)

    return response


@router.post("/report")
async def report_question(
    req: ReportQuestionRequest,
    user: AuthenticatedUser = Depends(get_current_user),
    idempotency_key: Optional[str] = Header(None, alias="Idempotency-Key"),
):
    check_rate_limit(f"report:{user.uid}", max_requests=10)

    if idempotency_key:
        cached = IdempotencyManager.get(idempotency_key)
        if cached and cached["status"] == "completed":
            return cached["result"]
        IdempotencyManager.start(idempotency_key)

    response = ReportingService.submit_report(
        user_id=user.uid,
        question_id=req.question_id,
        question_text=req.question_text,
        reason=req.reason,
        additional_feedback=req.additional_feedback,
        subject=req.subject,
        grade=req.grade,
        unit_number=req.unit_number,
    )

    if idempotency_key:
        IdempotencyManager.complete(idempotency_key, response)

    return response
