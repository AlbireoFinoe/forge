from datetime import datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel


class WorkoutProgressResponse(BaseModel):
    workout_id: UUID

    program_version_number: int
    day_name: str
    status: str

    started_at: datetime
    completed_at: datetime | None

    duration_minutes: float | None

    total_exercises: int
    completed_exercises: int
    skipped_exercises: int

    planned_sets: int
    completed_sets: int
    set_completion_rate: float

    total_reps: int

    external_volume_kg: Decimal
    average_rpe: Decimal | None


class ExerciseHistoryResponse(BaseModel):
    workout_id: UUID
    workout_completed_at: datetime

    exercise_code: str
    exercise_name: str
    exercise_status: str

    target_sets: int
    completed_sets: int
    set_completion_rate: float

    total_reps: int

    top_weight_kg: Decimal | None
    external_volume_kg: Decimal

    average_rpe: Decimal | None


class ExerciseProgressResponse(BaseModel):
    exercise_code: str
    exercise_name: str

    history_entries: int
    completed_sessions: int

    best_weight_kg: Decimal | None
    best_weight_reps: int | None

    best_session_volume_kg: Decimal

    latest_top_weight_kg: Decimal | None
    latest_volume_kg: Decimal | None
    latest_average_rpe: Decimal | None

    previous_top_weight_kg: Decimal | None
    previous_volume_kg: Decimal | None
    previous_average_rpe: Decimal | None

    volume_change_percent: float | None
    trend: str


class ProgressOverviewItemResponse(BaseModel):
    exercise_code: str
    exercise_name: str

    history_entries: int
    completed_sessions: int

    best_weight_kg: Decimal | None

    latest_top_weight_kg: Decimal | None
    latest_volume_kg: Decimal | None

    volume_change_percent: float | None
    trend: str


class ProgressOverviewResponse(BaseModel):
    total_exercises: int

    improving: int
    stable: int
    declining: int
    insufficient_data: int

    exercises: list[
        ProgressOverviewItemResponse
    ]