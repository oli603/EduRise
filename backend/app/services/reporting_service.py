import time
from typing import Dict, Any, List, Optional
from pydantic import BaseModel


class QuestionReportRecord(BaseModel):
    question_id: str
    question_text: str
    subject: str = "General"
    grade: str = "Grade 12"
    unit_number: int = 1
    report_count: int = 1
    reasons: Dict[str, int] = {}
    reporter_user_ids: List[str] = []
    status: str = "pending"  # pending, reviewing, resolved, dismissed
    first_reported_at: float
    last_reported_at: float
    admin_notes: Optional[str] = None
    reviewer: Optional[str] = None
    resolved_at: Optional[float] = None


# Aggregated in-memory / persistent report store: question_id -> QuestionReportRecord
_REPORTS_STORE: Dict[str, QuestionReportRecord] = {}


class ReportingService:
    @staticmethod
    def submit_report(
        user_id: str,
        question_id: str,
        question_text: str,
        reason: str,
        additional_feedback: Optional[str] = None,
        subject: str = "General",
        grade: str = "Grade 12",
        unit_number: int = 1,
    ) -> Dict[str, Any]:
        """
        Submits or aggregates a question report.
        Ensures distinct student counting (no inflation from repeated taps by same student).
        """
        now = time.time()
        clean_reason = reason.strip() if reason else "Other"

        if question_id in _REPORTS_STORE:
            report = _REPORTS_STORE[question_id]
            # Check if this student already reported this question
            if user_id not in report.reporter_user_ids:
                report.reporter_user_ids.append(user_id)
                report.report_count += 1
                report.reasons[clean_reason] = report.reasons.get(clean_reason, 0) + 1
            else:
                # Student already reported; reason count doesn't artificially inflate
                pass
            report.last_reported_at = now
            return {
                "status": "success",
                "message": "Report aggregated successfully.",
                "report_count": report.report_count,
            }
        else:
            # First report for this question
            report = QuestionReportRecord(
                question_id=question_id,
                question_text=question_text,
                subject=subject,
                grade=grade,
                unit_number=unit_number,
                report_count=1,
                reasons={clean_reason: 1},
                reporter_user_ids=[user_id],
                status="pending",
                first_reported_at=now,
                last_reported_at=now,
            )
            _REPORTS_STORE[question_id] = report
            return {
                "status": "success",
                "message": "Question reported successfully.",
                "report_count": 1,
            }

    @staticmethod
    def get_all_reports(status_filter: Optional[str] = None) -> List[Dict[str, Any]]:
        reports = list(_REPORTS_STORE.values())
        if status_filter and status_filter.lower() != "all":
            reports = [r for r in reports if r.status.lower() == status_filter.lower()]

        # Sort by report_count descending, then last_reported_at descending
        reports.sort(key=lambda r: (r.report_count, r.last_reported_at), reverse=True)
        return [r.model_dump() for r in reports]

    @staticmethod
    def update_report_status(
        question_id: str,
        new_status: str,
        admin_user_id: str,
        admin_notes: Optional[str] = None,
    ) -> Optional[Dict[str, Any]]:
        if question_id not in _REPORTS_STORE:
            return None

        report = _REPORTS_STORE[question_id]
        report.status = new_status
        report.reviewer = admin_user_id
        if admin_notes:
            report.admin_notes = admin_notes
        if new_status in ["resolved", "dismissed"]:
            report.resolved_at = time.time()

        return report.model_dump()

    @staticmethod
    def clear_for_testing():
        _REPORTS_STORE.clear()
