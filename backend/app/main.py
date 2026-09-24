from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import time

from .core.config import get_settings
from .api.routes import coach, questions, textbook, mock_exams, reports

settings = get_settings()

app = FastAPI(
    title="EduRise Coach API",
    description="Production Educational Intelligence & AI Tutoring Backend for EduRise",
    version="1.0.0",
)

# CORS Configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.get_cors_origins_list(),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def add_process_time_header(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    process_time = time.time() - start_time
    response.headers["X-Process-Time"] = str(process_time)
    return response


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "error": "InternalServerError",
            "message": "EduRise Coach encountered an unexpected error. Please try again later.",
            "detail": str(exc) if settings.ENVIRONMENT in ["development", "test"] else None,
        },
    )


# Health Check
@app.get("/health", tags=["Health"])
async def health_check():
    return {
        "status": "healthy",
        "service": "EduRise Coach API",
        "environment": settings.ENVIRONMENT,
        "model": settings.GEMINI_MODEL,
        "schema_version": settings.GENERATION_SCHEMA_VERSION,
    }


# Include Routers (/api/v1 and /api aliases)
for prefix in ["/api/v1", "/api"]:
    app.include_router(coach.router, prefix=prefix)
    app.include_router(questions.router, prefix=prefix)
    app.include_router(textbook.router, prefix=prefix)
    app.include_router(mock_exams.router, prefix=prefix)
    app.include_router(reports.router, prefix=prefix)
