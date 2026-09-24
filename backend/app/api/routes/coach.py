from typing import Optional, List, Dict, Any
from fastapi import APIRouter, Depends, Header
from pydantic import BaseModel
from ...core.security import get_current_user, AuthenticatedUser
from ...core.rate_limit import check_rate_limit
from ...core.idempotency import IdempotencyManager
from ...services.coach_service import CoachService

router = APIRouter(prefix="/coach", tags=["EduRise Coach"])
coach_service = CoachService()


class CoachChatRequest(BaseModel):
    message: str
    stream: str = "natural"
    grade: str = "Grade 12"
    subject: Optional[str] = None
    context: Optional[str] = None
    history: Optional[List[Dict[str, str]]] = None


@router.get("/quota")
@router.get("/status")
async def get_coach_quota(user: AuthenticatedUser = Depends(get_current_user)):
    return CoachService.get_quota_status(user.uid)


@router.post("/chat")
async def coach_chat(
    req: CoachChatRequest,
    user: AuthenticatedUser = Depends(get_current_user),
    idempotency_key: Optional[str] = Header(None, alias="Idempotency-Key"),
):
    check_rate_limit(f"coach_chat:{user.uid}")

    if idempotency_key:
        cached = IdempotencyManager.get(idempotency_key)
        if cached and cached["status"] == "completed":
            return cached["result"]
        IdempotencyManager.start(idempotency_key)

    authoritative_stream = user.stream if user.stream in ["natural", "social"] else req.stream

    response = await coach_service.get_coach_reply(
        user_id=user.uid,
        message=req.message,
        stream=authoritative_stream,
        grade=req.grade,
        subject=req.subject,
        context=req.context,
        history=req.history,
    )

    if idempotency_key:
        IdempotencyManager.complete(idempotency_key, response)

    return response
