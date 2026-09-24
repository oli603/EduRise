from typing import Optional
from fastapi import APIRouter, Depends, Header
from pydantic import BaseModel
from ...core.security import get_current_user, AuthenticatedUser
from ...core.rate_limit import check_rate_limit
from ...core.idempotency import IdempotencyManager
from ...services.mock_exam_service import MockExamService

router = APIRouter(prefix="/mock-exams", tags=["Predicted Mock Exams"])
mock_exam_service = MockExamService()


class GenerateMockExamRequest(BaseModel):
    subject: str
    stream: str = "natural"
    question_count: int = 50
    version: str = "1"


@router.post("/generate")
async def generate_mock_exam(
    req: GenerateMockExamRequest,
    user: AuthenticatedUser = Depends(get_current_user),
    idempotency_key: Optional[str] = Header(None, alias="Idempotency-Key"),
):
    check_rate_limit(f"mock_exam:{user.uid}", max_requests=10)
    if idempotency_key:
        cached = IdempotencyManager.get(idempotency_key)
        if cached and cached["status"] == "completed":
            return cached["result"]
        IdempotencyManager.start(idempotency_key)

    # Derive authoritative stream from authenticated user identity
    authoritative_stream = user.stream if user.stream in ["natural", "social"] else req.stream

    res = await mock_exam_service.get_predicted_mock_exam(
        subject=req.subject,
        stream=authoritative_stream,
        question_count=req.question_count,
        version=req.version,
    )

    if idempotency_key:
        IdempotencyManager.complete(idempotency_key, res)

    return res
