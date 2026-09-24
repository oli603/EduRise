from typing import List, Optional, Dict, Any
from ..providers.base_provider import AIProvider, ExplanationResult
from ..providers.gemini_provider import GeminiProvider
from .cache_service import CacheService


class QuestionService:
    def __init__(self, provider: Optional[AIProvider] = None):
        self.provider = provider or GeminiProvider()

    async def get_deep_explanation(
        self,
        question_id: str,
        question_text: str,
        options: List[str],
        correct_answer: str,
        existing_explanation: str,
        version: str = "1",
        selected_answer: Optional[str] = None,
        subject: Optional[str] = None,
        grade: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Retrieves deep explanation for Practice or Past Exam question.
        Enforces authoritative correct answer and aggressive caching.
        """
        # 1. Check Cache
        cache_key = CacheService.generate_cache_key(
            content_id=question_id,
            content_version=version,
            feature_type="explain_more",
            extra_key=correct_answer,
        )
        cached = CacheService.get(cache_key)
        if cached:
            return {
                "source": "cache",
                "question_id": question_id,
                **cached,
            }

        # 2. Generate with Provider
        result: ExplanationResult = await self.provider.generate_explanation(
            question_text=question_text,
            options=options,
            correct_answer=correct_answer,
            existing_explanation=existing_explanation,
            selected_answer=selected_answer,
            subject=subject,
            grade=grade,
        )

        data = result.model_dump()

        # 3. Cache result
        CacheService.set(
            cache_key=cache_key,
            data=data,
            content_id=question_id,
            content_version=version,
            feature_type="explain_more",
        )

        return {
            "source": "generated",
            "question_id": question_id,
            **data,
        }
