# EduRise Coach — Backend API Architecture

EduRise Coach is the server-side educational intelligence and AI tutoring subsystem for the EduRise mobile and web learning application.

---

## 1. Architecture Overview

```text
Flutter App (Student & Admin)
       │ (HTTPS + Firebase Auth Bearer Token + Idempotency-Key)
       ▼
FastAPI Backend (Python 3.12)
       ├── Auth Verification & Access Authorization (security.py)
       ├── Idempotency & Rate Limiting (idempotency.py, rate_limit.py)
       ├── Deterministic Caching Layer (cache_service.py)
       ├── AI Provider Abstraction (base_provider.py)
       │      └── GeminiProvider (gemini_provider.py)
       └── Subsystem Services (Coach, Questions, Textbooks, Quizzes, Mock Exams, Reports)
```

---

## 2. Setup & Local Development

### Prerequisites
- Python 3.12+ (managed automatically via `uv`)

### Installation & Run

1. **Install dependencies**:
   ```bash
   uv sync
   # or
   pip install -r requirements.txt
   ```

2. **Configure environment**:
   Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```

3. **Set Gemini API Key**:
   In `.env`, set:
   ```env
   GEMINI_API_KEY=your_actual_gemini_api_key_here
   GEMINI_MODEL=gemini-2.5-flash
   ```

4. **Start the API server**:
   ```bash
   uv run uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
   ```

5. **Run tests**:
   ```bash
   uv run pytest tests -v
   ```

---

## 3. Switching AI Providers & Models

To switch from Gemini Free to Gemini Paid, or to another Gemini model (e.g. `gemini-1.5-pro`):
1. Update `GEMINI_MODEL=gemini-1.5-pro` in `.env`.
2. To introduce another provider (e.g., Anthropic, OpenAI, or local model):
   - Implement the `AIProvider` interface in `app/providers/`.
   - Update `app/services/` instantiation to use the new provider class.
   - **Zero Flutter changes are required.**

---

## 4. API Endpoints Summary

| Endpoint | Method | Description |
| :--- | :--- | :--- |
| `/health` | `GET` | Health check & model status |
| `/api/v1/coach/quota` | `GET` | Student remaining daily quota |
| `/api/v1/coach/chat` | `POST` | EduRise Coach student chat |
| `/api/v1/questions/explain` | `POST` | Deep "Explain More" breakdown |
| `/api/v1/questions/report` | `POST` | Report a problematic question |
| `/api/v1/textbook/summary` | `POST` | Unit summary |
| `/api/v1/textbook/flashcards` | `POST` | High-yield flashcards |
| `/api/v1/textbook/ai-notes` | `POST` | Structured curriculum AI notes |
| `/api/v1/textbook/understand-unit` | `POST` | Simplified teacher-style breakdown |
| `/api/v1/textbook/quiz` | `POST` | Exactly 7-question unit quiz |
| `/api/v1/mock-exams/generate` | `POST` | Predicted Entrance Mock Exam |
| `/api/v1/admin/reports` | `GET` | Admin list aggregated reports |
| `/api/v1/admin/reports/{qid}` | `PATCH` | Admin review and resolve report |
