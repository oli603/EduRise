import time
from typing import Dict, Any, Optional
from .config import get_settings

settings = get_settings()

# In-memory store for idempotency: key -> {"status": "in_progress" | "completed", "result": Any, "timestamp": float}
_IDEMPOTENCY_STORE: Dict[str, Dict[str, Any]] = {}


class IdempotencyManager:
    @staticmethod
    def get(key: str) -> Optional[Dict[str, Any]]:
        if not key:
            return None
        record = _IDEMPOTENCY_STORE.get(key)
        if not record:
            return None
        # Check TTL
        if time.time() - record["timestamp"] > settings.IDEMPOTENCY_TTL_SECONDS:
            del _IDEMPOTENCY_STORE[key]
            return None
        return record

    @staticmethod
    def start(key: str) -> bool:
        """
        Marks an operation as in_progress.
        Returns True if fresh operation, False if already in-progress or completed.
        """
        if not key:
            return True
        existing = IdempotencyManager.get(key)
        if existing:
            return False
        _IDEMPOTENCY_STORE[key] = {
            "status": "in_progress",
            "result": None,
            "timestamp": time.time(),
        }
        return True

    @staticmethod
    def complete(key: str, result: Any):
        if not key:
            return
        _IDEMPOTENCY_STORE[key] = {
            "status": "completed",
            "result": result,
            "timestamp": time.time(),
        }

    @staticmethod
    def clear(key: str):
        if key in _IDEMPOTENCY_STORE:
            del _IDEMPOTENCY_STORE[key]
