from typing import Dict, Any, Optional, List
from fastapi import HTTPException, status
from ..providers.base_provider import AIProvider, CoachReplyResult
from ..providers.gemini_provider import GeminiProvider
from .usage_service import UsageService
from .cache_service import CacheService


class CoachService:
    def __init__(self, provider: Optional[AIProvider] = None):
        self.provider = provider or GeminiProvider()

    async def get_coach_reply(
        self,
        user_id: str,
        message: str,
        stream: str = "natural",
        grade: str = "Grade 12",
        subject: Optional[str] = None,
        context: Optional[str] = None,
        history: Optional[List[Dict[str, str]]] = None,
    ) -> Dict[str, Any]:
        """
        Processes educational question for EduRise Coach.
        Enforces daily question quota, stream context, and curriculum guardrails.
        """
        # 1. Check daily quota
        can_proceed = UsageService.check_and_increment(user_id)
        if not can_proceed:
            remaining, limit = UsageService.get_remaining_quota(user_id)
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"You have reached your daily EduRise Coach limit of {limit} questions. Your quota will reset tomorrow!",
            )

        # 2. Check cache for generic factual queries
        cache_key = CacheService.generate_cache_key(
            content_id=f"coach_qa:{stream}:{subject or 'all'}",
            content_version="1",
            feature_type="chat",
            extra_key=message.strip().lower(),
        )
        cached = CacheService.get(cache_key)
        remaining, limit = UsageService.get_remaining_quota(user_id)

        if cached:
            return {
                "source": "cache",
                "remaining_quota": remaining,
                "daily_limit": limit,
                "quota": {"remaining_today": remaining, "daily_limit": limit},
                **cached,
            }

        # 3. Generate response with provider
        result: CoachReplyResult = await self.provider.generate_coach_reply(
            user_message=message,
            student_stream=stream,
            student_grade=grade,
            subject=subject,
            relevant_context=context,
            history=history,
        )

        data = result.model_dump()

        # 4. Cache response
        CacheService.set(
            cache_key=cache_key,
            data=data,
            content_id="coach_qa",
            content_version="1",
            feature_type="chat",
        )

        return {
            "source": "generated",
            "remaining_quota": remaining,
            "daily_limit": limit,
            "quota": {"remaining_today": remaining, "daily_limit": limit},
            **data,
        }

    @staticmethod
    def get_quota_status(user_id: str) -> Dict[str, int]:
        remaining, limit = UsageService.get_remaining_quota(user_id)
        return {"remaining_today": remaining, "daily_limit": limit}
