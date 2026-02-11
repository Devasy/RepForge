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
    sessions: List[Dict[str, Any]]
    routines: List[Dict[str, Any]]
    targets: List[Dict[str, Any]]
    muscleGroups: List[Dict[str, Any]]
    customExercises: List[Dict[str, Any]]
    exportDate: str  # ISO string from Dart
    backup_received_at: datetime = Field(default_factory=_utcnow)


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
