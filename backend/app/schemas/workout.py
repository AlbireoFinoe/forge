from datetime import datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, Field


class WorkoutStartRequest(BaseModel):
    program_day_id: UUID


class WorkoutSetLogRequest(BaseModel):
    actual_reps: int = Field(
        ge=0,
    )

    weight_kg: Decimal | None = Field(
        default=None,
        ge=0,
    )

    rpe: Decimal | None = Field(
        default=None,
        ge=1,
        le=10,
    )


class WorkoutSetResponse(BaseModel):
    id: UUID
    set_number: int

    actual_reps: int | None
    weight_kg: Decimal | None
    rpe: Decimal | None

    is_completed: bool
    completed_at: datetime | None


class WorkoutExerciseResponse(BaseModel):
    id: UUID

    program_exercise_id: UUID | None
    exercise_id: UUID | None

    exercise_code: str
    exercise_name: str
    exercise_order: int

    target_sets: int
    target_min_reps: int
    target_max_reps: int
    target_rest_seconds: int

    status: str
    notes: str | None

    sets: list[
        WorkoutSetResponse
    ]


class WorkoutSessionResponse(BaseModel):
    id: UUID

    training_program_id: UUID | None
    program_day_id: UUID | None

    program_version_number: int
    program_name: str

    day_name: str
    day_of_week: int
    day_order: int

    status: str
    notes: str | None

    started_at: datetime
    completed_at: datetime | None
    created_at: datetime

    exercises: list[
        WorkoutExerciseResponse
    ]


class WorkoutSummaryResponse(BaseModel):
    id: UUID

    program_version_number: int
    program_name: str

    day_name: str
    day_of_week: int
    day_order: int

    status: str

    started_at: datetime
    completed_at: datetime | None