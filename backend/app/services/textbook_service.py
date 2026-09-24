from typing import Dict, Any, Optional
from ..providers.base_provider import AIProvider
from ..providers.gemini_provider import GeminiProvider
from .cache_service import CacheService


class TextbookService:
    def __init__(self, provider: Optional[AIProvider] = None):
        self.provider = provider or GeminiProvider()

    async def get_summary(
        self,
        unit_id: str,
        grade: str,
        subject: str,
        unit_number: int,
        unit_name: str,
        textbook_context: str = "",
        version: str = "1",
    ) -> Dict[str, Any]:
        cache_key = CacheService.generate_cache_key(
            content_id=unit_id,
            content_version=version,
            feature_type="summary",
        )
        cached = CacheService.get(cache_key)
        if cached:
            return {"source": "cache", "unit_id": unit_id, **cached}

        result = await self.provider.generate_summary(
            grade=grade,
            subject=subject,
            unit_number=unit_number,
            unit_name=unit_name,
            textbook_context=textbook_context,
        )
        data = result.model_dump()
        CacheService.set(cache_key, data, unit_id, version, "summary")
        return {"source": "generated", "unit_id": unit_id, **data}

    async def get_flashcards(
        self,
        unit_id: str,
        grade: str,
        subject: str,
        unit_number: int,
        unit_name: str,
        textbook_context: str = "",
        version: str = "1",
    ) -> Dict[str, Any]:
        cache_key = CacheService.generate_cache_key(
            content_id=unit_id,
            content_version=version,
            feature_type="flashcards",
        )
        cached = CacheService.get(cache_key)
        if cached:
            return {"source": "cache", "unit_id": unit_id, **cached}

        result = await self.provider.generate_flashcards(
            grade=grade,
            subject=subject,
            unit_number=unit_number,
            unit_name=unit_name,
            textbook_context=textbook_context,
        )
        data = result.model_dump()
        CacheService.set(cache_key, data, unit_id, version, "flashcards")
        return {"source": "generated", "unit_id": unit_id, **data}

    async def get_ai_notes(
        self,
        unit_id: str,
        grade: str,
        subject: str,
        unit_number: int,
        unit_name: str,
        textbook_context: str = "",
        version: str = "1",
    ) -> Dict[str, Any]:
        cache_key = CacheService.generate_cache_key(
            content_id=unit_id,
            content_version=version,
            feature_type="ai_notes",
        )
        cached = CacheService.get(cache_key)
        if cached:
            return {"source": "cache", "unit_id": unit_id, **cached}

        result = await self.provider.generate_ai_notes(
            grade=grade,
            subject=subject,
            unit_number=unit_number,
            unit_name=unit_name,
            textbook_context=textbook_context,
        )
        data = result.model_dump()
        CacheService.set(cache_key, data, unit_id, version, "ai_notes")
        return {"source": "generated", "unit_id": unit_id, **data}

    async def get_understand_unit(
        self,
        unit_id: str,
        grade: str,
        subject: str,
        unit_number: int,
        unit_name: str,
        textbook_context: str = "",
        version: str = "1",
    ) -> Dict[str, Any]:
        cache_key = CacheService.generate_cache_key(
            content_id=unit_id,
            content_version=version,
            feature_type="understand_unit",
        )
        cached = CacheService.get(cache_key)
        if cached:
            return {"source": "cache", "unit_id": unit_id, **cached}

        result = await self.provider.generate_understand_unit(
            grade=grade,
            subject=subject,
            unit_number=unit_number,
            unit_name=unit_name,
            textbook_context=textbook_context,
        )
        data = result.model_dump()
        CacheService.set(cache_key, data, unit_id, version, "understand_unit")
        return {"source": "generated", "unit_id": unit_id, **data}

    async def get_quiz(
        self,
        unit_id: str,
        grade: str,
        subject: str,
        unit_number: int,
        unit_name: str,
        textbook_context: str = "",
        version: str = "1",
    ) -> Dict[str, Any]:
        """
        Generates/retrieves ONE quiz with EXACTLY 7 questions.
        Scores are NOT saved or tracked in progress history.
        """
        cache_key = CacheService.generate_cache_key(
            content_id=unit_id,
            content_version=version,
            feature_type="quiz_7q",
        )
        cached = CacheService.get(cache_key)
        if cached:
            return {"source": "cache", "unit_id": unit_id, **cached}

        result = await self.provider.generate_quiz(
            grade=grade,
            subject=subject,
            unit_number=unit_number,
            unit_name=unit_name,
            textbook_context=textbook_context,
        )
        data = result.model_dump()
        CacheService.set(cache_key, data, unit_id, version, "quiz_7q")
        return {"source": "generated", "unit_id": unit_id, **data}
