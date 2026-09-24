from typing import Optional, List, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from ...core.security import require_admin, get_current_user, AuthenticatedUser
from ...services.reporting_service import ReportingService

router = APIRouter(tags=["Question Reports"])


class SubmitReportRequest(BaseModel):
    question_id: str
    question_text: Optional[str] = "Question"
    reason: str
    details: Optional[str] = None
    subject: Optional[str] = "General"
    grade: Optional[str] = "Grade 12"
    unit_or_year: Optional[str] = "1"
    correct_answer: Optional[str] = None
    student_answer: Optional[str] = None


class UpdateReportStatusRequest(BaseModel):
    status: str  # pending, reviewing, resolved, dismissed
    admin_notes: Optional[str] = None


# Student report submission endpoints
@router.post("/reports/submit")
@router.post("/admin/reports/submit")
async def submit_question_report(
    req: SubmitReportRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    unit_num = 1
    if req.unit_or_year:
        try:
            unit_num = int(req.unit_or_year)
        except ValueError:
            unit_num = 1

    return ReportingService.submit_report(
        user_id=user.uid,
        question_id=req.question_id,
        question_text=req.question_text or "Question",
        reason=req.reason,
        additional_feedback=req.details,
        subject=req.subject or "General",
        grade=req.grade or "Grade 12",
        unit_number=unit_num,
    )


# Admin report listing endpoints
@router.get("/admin/reports")
@router.get("/reports/")
@router.get("/reports")
async def list_question_reports(
    status_filter: Optional[str] = None,
    admin: AuthenticatedUser = Depends(require_admin),
):
    return ReportingService.get_all_reports(status_filter=status_filter)


# Admin report status update endpoints
@router.patch("/admin/reports/{question_id}")
@router.patch("/reports/{question_id}")
async def update_question_report(
    question_id: str,
    req: UpdateReportStatusRequest,
    admin: AuthenticatedUser = Depends(require_admin),
):
    updated = ReportingService.update_report_status(
        question_id=question_id,
        new_status=req.status,
        admin_user_id=admin.uid,
        admin_notes=req.admin_notes,
    )
    if not updated:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No report found for question {question_id}",
        )
    return updated
