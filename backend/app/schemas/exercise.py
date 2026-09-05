import uuid

from pydantic import BaseModel


class ExerciseSummaryResponse(BaseModel):
    id: uuid.UUID
    code: str
    name: str

    primary_muscle_code: str
    primary_muscle_name: str

    movement_pattern: str
    difficulty: str
    is_compound: bool

    min_reps: int
    max_reps: int
    rest_seconds: int


class ExerciseEquipmentResponse(BaseModel):
    code: str
    name: str


class ExerciseSecondaryMuscleResponse(BaseModel):
    code: str
    name: str
    contribution_weight: float


class ExerciseDetailResponse(ExerciseSummaryResponse):
    equipment: list[ExerciseEquipmentResponse]
    secondary_muscles: list[
        ExerciseSecondaryMuscleResponse
    ]