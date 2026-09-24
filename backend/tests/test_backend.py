import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.services.cache_service import CacheService
from app.services.usage_service import UsageService
from app.services.reporting_service import ReportingService
from app.core.idempotency import IdempotencyManager

client = TestClient(app)

AUTH_HEADER = {"Authorization": "Bearer test_token_student_123"}
SOCIAL_AUTH_HEADER = {"Authorization": "Bearer test_token_social_student_456"}
ADMIN_AUTH_HEADER = {"Authorization": "Bearer test_token_admin_999"}


@pytest.fixture(autouse=True)
def clean_stores():
    CacheService.clear_all()
    UsageService.reset_usage_for_testing()
    ReportingService.clear_for_testing()


# ============================================================
# 1. HEALTH & FAIL-CLOSED SECURITY TESTS
# ============================================================

import base64
import json
import time


def _make_mock_jwt(payload: dict) -> str:
    header = {"alg": "RS256", "typ": "JWT"}
    h_b64 = base64.urlsafe_b64encode(json.dumps(header).encode()).decode().rstrip("=")
    p_b64 = base64.urlsafe_b64encode(json.dumps(payload).encode()).decode().rstrip("=")
    sig_b64 = base64.urlsafe_b64encode(b"mock_sig").decode().rstrip("=")
    return f"{h_b64}.{p_b64}.{sig_b64}"


def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "service" in data


# Test 1 — No Authorization header -> 401
def test_unauthenticated_request_rejected():
    response = client.get("/api/v1/coach/quota")
    assert response.status_code == 401
    assert "detail" in response.json()


# Test 2 — Malformed Authorization header -> 401
def test_malformed_auth_header_rejected():
    for bad_header in [
        {"Authorization": "Basic invalid_credentials"},
        {"Authorization": "Bearer"},
        {"Authorization": "Bearer "},
        {"Authorization": "Token 12345"},
        {"Authorization": "InvalidAuthScheme"},
    ]:
        res = client.get("/api/v1/coach/quota", headers=bad_header)
        assert res.status_code == 401


# Test 3 — Invalid / Corrupted Firebase token -> 401
def test_invalid_firebase_token_rejected():
    for bad_token in [
        "not_a_jwt",
        "only_one_part",
        "part1.part2",
        "part1.part2.part3.part4",
        "invalid_base64.invalid_base64.invalid_base64",
    ]:
        res = client.get(
            "/api/v1/coach/quota",
            headers={"Authorization": f"Bearer {bad_token}"},
        )
        assert res.status_code == 401
        assert "Invalid" in res.json()["detail"] or "Malformed" in res.json()["detail"]


# Test 4 — Expired Firebase token -> 401
def test_expired_firebase_token_rejected():
    past_exp = int(time.time()) - 3600  # 1 hour ago
    expired_jwt = _make_mock_jwt({"sub": "student_expired", "exp": past_exp})
    res = client.get(
        "/api/v1/coach/quota",
        headers={"Authorization": f"Bearer {expired_jwt}"},
    )
    assert res.status_code == 401


# Test 5 — Firebase verification failure (missing UID or unverifiable token) -> 401 (NO fallback user!)
def test_missing_uid_token_rejected_no_fallback():
    future_exp = int(time.time()) + 3600
    # Payload has email but NO sub/user_id
    token_no_uid = _make_mock_jwt({"email": "test@edurise.edu", "exp": future_exp})
    res = client.get(
        "/api/v1/coach/quota",
        headers={"Authorization": f"Bearer {token_no_uid}"},
    )
    assert res.status_code == 401



# Test 10 — Forged / Self-Signed JWT with fabricated claims (sub, role, is_paid) -> REJECTED (401)
def test_forged_jwt_with_fabricated_claims_rejected():
    """
    Attacker fabricates a JWT with elevated claims (is_paid=True, role=founder, sub=victim)
    signed with an unauthorized/fake key. Cryptographic verification MUST reject it.
    """
    forged_jwt = _make_mock_jwt({
        "sub": "fake_user_attacker",
        "email": "attacker@darkweb.org",
        "role": "founder",
        "is_paid": True,
        "exp": int(time.time()) + 3600,
    })
    res = client.get(
        "/api/v1/coach/quota",
        headers={"Authorization": f"Bearer {forged_jwt}"},
    )
    assert res.status_code == 401
    assert "Invalid or unverifiable" in res.json()["detail"] or "invalid" in res.json()["detail"].lower()


# Test 11 — Tampered payload (changing is_paid=False to is_paid=True) -> REJECTED (401)
def test_tampered_is_paid_claim_rejected():
    """
    Attacker modifies a token payload to change is_paid from False to True without valid Google signature.
    Verification MUST reject the tampered token.
    """
    original_payload = {"sub": "student_free_1", "is_paid": False, "exp": int(time.time()) + 3600}
    tampered_payload = {"sub": "student_free_1", "is_paid": True, "exp": int(time.time()) + 3600}
    
    # Tamper payload while keeping previous signature
    header = {"alg": "RS256", "kid": "some_kid"}
    h_b64 = base64.urlsafe_b64encode(json.dumps(header).encode()).decode().rstrip("=")
    p_b64 = base64.urlsafe_b64encode(json.dumps(tampered_payload).encode()).decode().rstrip("=")
    fake_sig = base64.urlsafe_b64encode(b"original_sig_unmatched").decode().rstrip("=")
    tampered_jwt = f"{h_b64}.{p_b64}.{fake_sig}"

    res = client.get(
        "/api/v1/coach/quota",
        headers={"Authorization": f"Bearer {tampered_jwt}"},
    )
    assert res.status_code == 401


# Test 12 — Direct verification unit test with mocked Google verify_firebase_token
def test_cryptographic_verification_claims_mapping(monkeypatch):
    from google.oauth2 import id_token as google_id_token
    from app.core.security import get_current_user
    import asyncio

    # Simulate valid signature verification by Google auth
    def mock_verify_valid(token, request, audience=None):
        return {
            "sub": "verified_student_123",
            "email": "verified@edurise.edu",
            "role": "student",
            "is_paid": True,
            "stream": "natural",
        }

    monkeypatch.setattr(google_id_token, "verify_firebase_token", mock_verify_valid)
    user = asyncio.run(get_current_user("Bearer real_google_signed_jwt"))
    assert user.uid == "verified_student_123"
    assert user.is_paid is True
    assert user.role == "student"

    # Simulate signature verification failure by Google auth
    def mock_verify_invalid(token, request, audience=None):
        raise ValueError("Invalid cryptographic signature or certificate")

    monkeypatch.setattr(google_id_token, "verify_firebase_token", mock_verify_invalid)
    from fastapi import HTTPException
    with pytest.raises(HTTPException) as exc_info:
        asyncio.run(get_current_user("Bearer forged_tampered_jwt"))
    assert exc_info.value.status_code == 401




# ============================================================
# 2. CACHING & IDEMPOTENCY TESTS
# ============================================================

def test_explain_more_caching():
    payload = {
        "question_id": "q_bio_101",
        "question_text": "What is the primary site of photosynthesis?",
        "options": ["Chloroplast", "Mitochondria", "Nucleus", "Ribosome"],
        "correct_answer": "Chloroplast",
        "existing_explanation": "Chloroplasts contain chlorophyll.",
        "version": "1",
    }

    # First call: Generated
    res1 = client.post("/api/v1/questions/explain", json=payload, headers=AUTH_HEADER)
    assert res1.status_code == 200
    data1 = res1.json()
    assert data1["source"] == "generated"
    assert "why_correct" in data1
    assert "why_other_options_wrong" in data1

    # Second call: Retrieved from Cache
    res2 = client.post("/api/v1/questions/explain", json=payload, headers=AUTH_HEADER)
    assert res2.status_code == 200
    data2 = res2.json()
    assert data2["source"] == "cache"
    assert data2["why_correct"] == data1["why_correct"]


def test_cache_invalidation_on_content_version_change():
    payload_v1 = {
        "unit_id": "unit_bio_1",
        "grade": "Grade 11",
        "subject": "Biology",
        "unit_number": 1,
        "unit_name": "Living Things",
        "textbook_context": "Living things display metabolic activity.",
        "version": "1",
    }
    res_v1 = client.post("/api/v1/textbook/summary", json=payload_v1, headers=AUTH_HEADER)
    assert res_v1.json()["source"] == "generated"

    # Same payload, version 1 -> Cache Hit
    res_v1_cached = client.post("/api/v1/textbook/summary", json=payload_v1, headers=AUTH_HEADER)
    assert res_v1_cached.json()["source"] == "cache"

    # Updated version 2 -> Invalidation / New Generation
    payload_v2 = {**payload_v1, "version": "2"}
    res_v2 = client.post("/api/v1/textbook/summary", json=payload_v2, headers=AUTH_HEADER)
    assert res_v2.json()["source"] == "generated"


def test_request_idempotency_prevents_duplicate_calls():
    headers = {**AUTH_HEADER, "Idempotency-Key": "unique_idem_key_999"}
    payload = {
        "message": "Explain osmosis simply.",
        "stream": "natural",
        "grade": "Grade 12",
    }

    res1 = client.post("/api/v1/coach/chat", json=payload, headers=headers)
    assert res1.status_code == 200

    # Repeating with same idempotency key returns stored result
    res2 = client.post("/api/v1/coach/chat", json=payload, headers=headers)
    assert res2.status_code == 200
    assert res2.json()["reply"] == res1.json()["reply"]


# ============================================================
# 3. DAILY COACH QUOTA LIMITS
# ============================================================

def test_daily_coach_quota_enforcement():
    # Check initial quota
    q_res = client.get("/api/v1/coach/quota", headers=AUTH_HEADER)
    assert q_res.status_code == 200
    initial_remaining = q_res.json()["remaining_today"]
    assert initial_remaining > 0

    # Exhaust quota
    for i in range(initial_remaining):
        res = client.post(
            "/api/v1/coach/chat",
            json={"message": f"Question {i}", "stream": "natural", "grade": "Grade 12"},
            headers=AUTH_HEADER,
        )
        assert res.status_code == 200

    # Next call should be blocked with 429 Too Many Requests
    blocked_res = client.post(
        "/api/v1/coach/chat",
        json={"message": "Exceeded question", "stream": "natural", "grade": "Grade 12"},
        headers=AUTH_HEADER,
    )
    assert blocked_res.status_code == 429
    assert "daily EduRise Coach limit" in blocked_res.json()["detail"]


# ============================================================
# 4. BOOK TOOLS & EXACTLY 7-QUESTION QUIZ
# ============================================================

def test_book_tools_summary_flashcards_ai_notes_understand():
    base_payload = {
        "unit_id": "unit_chem_2",
        "grade": "Grade 12",
        "subject": "Chemistry",
        "unit_number": 2,
        "unit_name": "Electrochemistry",
        "textbook_context": "Electrochemistry deals with oxidation-reduction reactions.",
        "version": "1",
    }

    # Summary
    res_sum = client.post("/api/v1/textbook/summary", json=base_payload, headers=AUTH_HEADER)
    assert res_sum.status_code == 200
    assert "overview" in res_sum.json()
    assert "key_points" in res_sum.json()

    # Flashcards
    res_fc = client.post("/api/v1/textbook/flashcards", json=base_payload, headers=AUTH_HEADER)
    assert res_fc.status_code == 200
    assert len(res_fc.json()["flashcards"]) >= 4


    # AI Notes
    res_notes = client.post("/api/v1/textbook/ai-notes", json=base_payload, headers=AUTH_HEADER)
    assert res_notes.status_code == 200
    assert "key_concepts" in res_notes.json()
    assert "exam_focused_points" in res_notes.json()

    # Understand Unit
    res_und = client.post("/api/v1/textbook/understand-unit", json=base_payload, headers=AUTH_HEADER)
    assert res_und.status_code == 200
    assert "main_ideas_simplified" in res_und.json()


def test_book_quiz_generates_exactly_7_questions():
    payload = {
        "unit_id": "unit_phys_3",
        "grade": "Grade 11",
        "subject": "Physics",
        "unit_number": 3,
        "unit_name": "Dynamics",
        "textbook_context": "Newton's laws of motion define classical mechanics.",
        "version": "1",
    }

    res = client.post("/api/v1/textbook/quiz", json=payload, headers=AUTH_HEADER)
    assert res.status_code == 200
    data = res.json()
    questions = data.get("questions", [])

    # Strict requirement: EXACTLY 7 questions
    assert len(questions) == 7

    for q in questions:
        assert "question" in q
        assert len(q["options"]) == 4
        assert "correct_answer" in q
        assert "explanation" in q


def test_coach_chat_with_subject():
    payload = {
        "message": "Explain vectors in 2D space.",
        "stream": "natural",
        "grade": "Grade 11",
        "subject": "Physics",
    }
    res = client.post("/api/v1/coach/chat", json=payload, headers=AUTH_HEADER)
    assert res.status_code == 200
    data = res.json()
    assert "reply" in data
    assert "suggestions" in data


# ============================================================
# 5. PREDICTED MOCK EXAM
# ============================================================

def test_predicted_mock_exam_generation():
    payload = {
        "subject": "Biology",
        "stream": "natural",
        "question_count": 10,
        "version": "1",
    }
    res = client.post("/api/v1/mock-exams/generate", json=payload, headers=AUTH_HEADER)
    assert res.status_code == 200
    data = res.json()
    assert data["subject"] == "Biology"
    assert data["stream"] == "natural"
    assert len(data["questions"]) == 10
    assert "blueprint_summary" in data


def test_predicted_mock_exam_mathematics_blueprint():
    payload = {
        "subject": "Mathematics",
        "stream": "natural",
        "question_count": 45,
        "version": "1",
    }
    res = client.post("/api/v1/mock-exams/generate", json=payload, headers=AUTH_HEADER)
    assert res.status_code == 200
    data = res.json()
    assert data["subject"] == "Mathematics"
    assert len(data["questions"]) == 45
    assert data["duration_minutes"] == 180


def test_predicted_mock_exam_social_science_economics():
    payload = {
        "subject": "Economics",
        "stream": "social",
        "question_count": 50,
        "version": "1",
    }
    res = client.post("/api/v1/mock-exams/generate", json=payload, headers=SOCIAL_AUTH_HEADER)
    assert res.status_code == 200
    data = res.json()
    assert data["subject"] == "Economics"
    assert data["stream"] == "social"
    assert len(data["questions"]) == 50
    assert data["duration_minutes"] == 120


# ============================================================
# 6. QUESTION REPORTING AGGREGATION & ADMIN MANAGEMENT
# ============================================================

def test_question_reporting_distinct_counting_and_admin_workflow():
    q_id = "Q_MATH_2016_42"
    report_payload = {
        "question_id": q_id,
        "question_text": "Calculate the limit as x approaches 0...",
        "reason": "Wrong answer",
        "additional_feedback": "Option B is mathematically correct instead of C.",
        "subject": "Mathematics",
        "grade": "Grade 12",
        "unit_number": 1,
    }

    # Student A reports question -> report_count = 1
    res1 = client.post("/api/v1/questions/report", json=report_payload, headers={"Authorization": "Bearer test_token_studentA"})
    assert res1.status_code == 200
    assert res1.json()["report_count"] == 1

    # Student A reports AGAIN (duplicate tap) -> report_count remains 1 (NO INFLATION!)
    res1_dup = client.post("/api/v1/questions/report", json=report_payload, headers={"Authorization": "Bearer test_token_studentA"})
    assert res1_dup.status_code == 200
    assert res1_dup.json()["report_count"] == 1

    # Student B reports question -> report_count = 2
    res2 = client.post("/api/v1/questions/report", json=report_payload, headers={"Authorization": "Bearer test_token_studentB"})
    assert res2.status_code == 200
    assert res2.json()["report_count"] == 2

    # Admin lists reports
    admin_list_res = client.get("/api/v1/admin/reports", headers=ADMIN_AUTH_HEADER)
    assert admin_list_res.status_code == 200
    reports = admin_list_res.json()
    assert len(reports) == 1
    assert reports[0]["question_id"] == q_id
    assert reports[0]["report_count"] == 2
    assert reports[0]["status"] == "pending"

    # Admin updates report status to "resolved"
    patch_res = client.patch(
        f"/api/v1/admin/reports/{q_id}",
        json={"status": "resolved", "admin_notes": "Corrected answer key to Option B."},
        headers=ADMIN_AUTH_HEADER,
    )
    assert patch_res.status_code == 200
    updated = patch_res.json()
    assert updated["status"] == "resolved"
    assert updated["admin_notes"] == "Corrected answer key to Option B."
    assert updated["reviewer"] == "admin_999"
