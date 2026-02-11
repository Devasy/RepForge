from pydantic import BaseModel, Field
from typing import List, Dict, Any, Optional
from datetime import datetime, timezone


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class UsageStats(BaseModel):
    user_app_id: str  # unique per-install identifier
    total_workouts: int
    weekly_workouts: int
    weekly_volume: float
    exercises_this_week: int
    app_version: Optional[str] = None
    platform: Optional[str] = None  # android / ios / web
    report_date: datetime = Field(default_factory=_utcnow)


class BackupData(BaseModel):
    user_app_id: str
    sessions: List[Any]  # May arrive as List[str] or List[dict]
    routines: List[Any]
    targets: List[Any]
    muscleGroups: List[Any]
    customExercises: List[Any]
    exportDate: str  # ISO string from Dart
    backup_received_at: datetime = Field(default_factory=_utcnow)

    def parsed_backup(self) -> dict:
        """Return a copy with any JSON-string items decoded to dicts."""
        import json
        def _parse_list(items: list) -> list:
            out = []
            for item in items:
                if isinstance(item, str):
                    try:
                        out.append(json.loads(item))
                    except (json.JSONDecodeError, TypeError):
                        out.append(item)
                else:
                    out.append(item)
            return out

        data = self.model_dump()
        for key in ('sessions', 'routines', 'targets', 'muscleGroups', 'customExercises'):
            data[key] = _parse_list(data.get(key, []))
        return data


class AppEvent(BaseModel):
    """Lightweight event for tracking feature usage, app opens, etc."""
    user_app_id: str
    event: str  # e.g. "app_open", "workout_started", "backup_triggered"
    metadata: Optional[Dict[str, Any]] = None
    app_version: Optional[str] = None
    platform: Optional[str] = None
    timestamp: datetime = Field(default_factory=_utcnow)


class HeartbeatPayload(BaseModel):
    """Minimal ping sent on every app open for DAU/MAU calculation."""
    user_app_id: str
    app_version: Optional[str] = None
    platform: Optional[str] = None
    timestamp: datetime = Field(default_factory=_utcnow)
