from pydantic import BaseModel
from typing import List, Dict, Any, Optional
from datetime import datetime

class UsageStats(BaseModel):
    total_workouts: int
    weekly_workouts: int
    weekly_volume: float
    exercises_this_week: int
    report_date: datetime = datetime.now()

class BackupData(BaseModel):
    sessions: List[Dict[str, Any]]
    routines: List[Dict[str, Any]]
    targets: List[Dict[str, Any]]
    muscleGroups: List[Dict[str, Any]]
    customExercises: List[Dict[str, Any]]
    exportDate: str # Since it's ISO string from Dart
    backup_received_at: datetime = datetime.now()
