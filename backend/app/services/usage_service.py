import time
from datetime import datetime, timezone
from typing import Dict, Tuple
from ..core.config import get_settings

settings = get_settings()

# In-memory daily usage tracking: f"{user_id}:{date_str}" -> count
_DAILY_USAGE_STORE: Dict[str, int] = {}


class UsageService:
    @staticmethod
    def _get_today_key(user_id: str) -> str:
        today_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        return f"{user_id}:{today_str}"

    @staticmethod
    def get_remaining_quota(user_id: str) -> Tuple[int, int]:
        """Returns (remaining_questions, daily_limit)."""
        key = UsageService._get_today_key(user_id)
        used = _DAILY_USAGE_STORE.get(key, 0)
        limit = settings.DAILY_COACH_LIMIT
        remaining = max(0, limit - used)
        return remaining, limit

    @staticmethod
    def check_and_increment(user_id: str) -> bool:
        """
        Increments usage if quota remains.
        Returns True if successful, False if daily limit reached.
        """
        key = UsageService._get_today_key(user_id)
        used = _DAILY_USAGE_STORE.get(key, 0)
        limit = settings.DAILY_COACH_LIMIT
        if used >= limit:
            return False
        _DAILY_USAGE_STORE[key] = used + 1
        return True

    @staticmethod
    def reset_usage_for_testing():
        _DAILY_USAGE_STORE.clear()
