import json

from pydantic import BaseModel, Field, field_validator
from typing import Any, Optional
from datetime import datetime, timezone

MAX_LIST_ITEMS = 5000
MAX_JSON_NESTING_DEPTH = 20


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
    sessions: list[Any] = Field(default_factory=list, max_length=MAX_LIST_ITEMS)
    routines: list[Any] = Field(default_factory=list, max_length=MAX_LIST_ITEMS)
    targets: list[Any] = Field(default_factory=list, max_length=MAX_LIST_ITEMS)
    muscleGroups: list[Any] = Field(default_factory=list, max_length=MAX_LIST_ITEMS)
    customExercises: list[Any] = Field(default_factory=list, max_length=MAX_LIST_ITEMS)
    exportDate: str  # ISO string from Dart
    backup_received_at: datetime = Field(default_factory=_utcnow)

    @field_validator("sessions", "routines", "targets", "muscleGroups", "customExercises", mode="before")
    @classmethod
    def _enforce_list_size(cls, v: Any) -> Any:
        if isinstance(v, list) and len(v) > MAX_LIST_ITEMS:
            raise ValueError(f"List exceeds maximum of {MAX_LIST_ITEMS} items")
        return v

    @staticmethod
    def _parse_list(items: list) -> list:
        """Decode any JSON-string items; enforce nesting depth."""
        out: list = []
        for item in items:
            if isinstance(item, str):
                try:
                    # Custom decoder with depth guard
                    _depth_guard_decode(item, max_depth=MAX_JSON_NESTING_DEPTH)
                    out.append(json.loads(item))
                except (json.JSONDecodeError, TypeError, ValueError):
                    out.append(item)
            else:
                out.append(item)
        return out

    def parsed_backup(self) -> dict:
        """Return a copy with any JSON-string items decoded to dicts."""
        data = self.model_dump()
        for key in ("sessions", "routines", "targets", "muscleGroups", "customExercises"):
            data[key] = self._parse_list(data.get(key, []))
        return data


def _depth_guard_decode(s: str, max_depth: int = 20) -> None:
    """Raise ValueError if the JSON string nests deeper than max_depth."""
    depth = 0
    for ch in s:
        if ch in "{[":
            depth += 1
            if depth > max_depth:
                raise ValueError(f"JSON nesting exceeds maximum depth of {max_depth}")
        elif ch in "}]":
            depth -= 1


class AppEvent(BaseModel):
    """Lightweight event for tracking feature usage, app opens, etc."""
    user_app_id: str
    event: str  # e.g. "app_open", "workout_started", "backup_triggered"
    metadata: Optional[dict[str, Any]] = None
    app_version: Optional[str] = None
    platform: Optional[str] = None
    timestamp: datetime = Field(default_factory=_utcnow)


class HeartbeatPayload(BaseModel):
    """Minimal ping sent on every app open for DAU/MAU calculation."""
    user_app_id: str
    app_version: Optional[str] = None
    platform: Optional[str] = None
    timestamp: datetime = Field(default_factory=_utcnow)
