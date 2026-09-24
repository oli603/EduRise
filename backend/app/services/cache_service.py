import hashlib
import time
from typing import Dict, Any, Optional
from ..core.config import get_settings

settings = get_settings()

# In-memory and structured persistent cache
_CACHE_STORE: Dict[str, Dict[str, Any]] = {}


class CacheService:
    @staticmethod
    def generate_cache_key(
        content_id: str,
        content_version: str,
        feature_type: str,
        extra_key: Optional[str] = None,
    ) -> str:
        """
        Creates a deterministic cache key incorporating content identity,
        textbook/question version, feature type, and generation schema version.
        """
        raw = f"{content_id}:{content_version}:{feature_type}:{settings.GENERATION_SCHEMA_VERSION}:{extra_key or ''}"
        return hashlib.sha256(raw.encode("utf-8")).hexdigest()

    @staticmethod
    def get(cache_key: str) -> Optional[Dict[str, Any]]:
        record = _CACHE_STORE.get(cache_key)
        if not record:
            return None

        # Check TTL (if configured in hours)
        ttl_seconds = settings.CACHE_TTL_HOURS * 3600
        if time.time() - record.get("created_at", 0) > ttl_seconds:
            del _CACHE_STORE[cache_key]
            return None

        return record.get("data")

    @staticmethod
    def set(
        cache_key: str,
        data: Any,
        content_id: str,
        content_version: str,
        feature_type: str,
    ):
        _CACHE_STORE[cache_key] = {
            "data": data,
            "content_id": content_id,
            "content_version": content_version,
            "feature_type": feature_type,
            "created_at": time.time(),
        }

    @staticmethod
    def invalidate_content(content_id: str):
        """Invalidates all cached entries for a given textbook or question when its version updates."""
        keys_to_delete = [
            k for k, v in _CACHE_STORE.items() if v.get("content_id") == content_id
        ]
        for k in keys_to_delete:
            del _CACHE_STORE[k]

    @staticmethod
    def clear_all():
        _CACHE_STORE.clear()
