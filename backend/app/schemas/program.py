from datetime import datetime
from uuid import UUID

from pydantic import BaseModel


class ProgramWarningResponse(BaseModel):
    code: str
    message: str


class ProgramGenerateResponse(BaseModel):
    id: UUID
    name: str

    version_number: int
    generator_version: str

    goal: str
    status: str

    validation_passed: bool

    program_days: int
    program_exercises: int

    warnings: list[
        ProgramWarningResponse
    ]

    created_at: datetime


class ProgramExerciseResponse(BaseModel):
    id: UUID

    exercise_id: UUID
    exercise_code: str
    exercise_name: str

    exercise_order: int

    sets: int

    min_reps: int
    max_reps: int

    rest_seconds: int

    reason_codes: list[str]


class ProgramDayResponse(BaseModel):
    id: UUID

    day_of_week: int
    day_order: int

    name: str

    estimated_duration_minutes: int

    exercises: list[
        ProgramExerciseResponse
    ]


class ProgramDetailResponse(BaseModel):
    id: UUID
    name: str

    version_number: int
    generator_version: str

    goal: str
    status: str

    created_at: datetime

    days: list[
        ProgramDayResponse
    ]


class ProgramSummaryResponse(BaseModel):
    id: UUID
    name: str

    version_number: int
    generator_version: str

    goal: str
    status: str

    created_at: datetime