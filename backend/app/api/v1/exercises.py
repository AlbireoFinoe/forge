import uuid

from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    Query,
    status,
)
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.schemas.exercise import (
    ExerciseDetailResponse,
    ExerciseEquipmentResponse,
    ExerciseSecondaryMuscleResponse,
    ExerciseSummaryResponse,
)
from app.services.exercise import (
    get_exercise_by_id,
    get_exercise_equipment,
    get_exercise_secondary_muscles,
    get_exercises,
)


router = APIRouter(
    prefix="/exercises",
    tags=["Exercises"],
)


@router.get(
    "",
    response_model=list[ExerciseSummaryResponse],
)
def list_exercises(
    muscle: str | None = None,
    equipment: str | None = None,
    difficulty: str | None = None,
    compound: bool | None = None,
    search: str | None = Query(
        default=None,
        min_length=1,
        max_length=100,
    ),
    db: Session = Depends(get_db),
):
    rows = get_exercises(
        db=db,
        muscle=muscle,
        equipment=equipment,
        difficulty=difficulty,
        compound=compound,
        search=search,
    )

    return [
        ExerciseSummaryResponse(
            id=exercise.id,
            code=exercise.code,
            name=exercise.name,
            primary_muscle_code=muscle_group.code,
            primary_muscle_name=muscle_group.name,
            movement_pattern=exercise.movement_pattern,
            difficulty=exercise.difficulty,
            is_compound=exercise.is_compound,
            min_reps=exercise.default_min_reps,
            max_reps=exercise.default_max_reps,
            rest_seconds=exercise.default_rest_seconds,
        )
        for exercise, muscle_group in rows
    ]


@router.get(
    "/{exercise_id}",
    response_model=ExerciseDetailResponse,
)
def get_exercise(
    exercise_id: uuid.UUID,
    db: Session = Depends(get_db),
):
    row = get_exercise_by_id(
        db,
        exercise_id,
    )

    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Exercise not found",
        )

    exercise, muscle_group = row

    equipment = get_exercise_equipment(
        db,
        exercise,
    )

    secondary_rows = (
        get_exercise_secondary_muscles(
            db,
            exercise,
        )
    )

    return ExerciseDetailResponse(
        id=exercise.id,
        code=exercise.code,
        name=exercise.name,
        primary_muscle_code=muscle_group.code,
        primary_muscle_name=muscle_group.name,
        movement_pattern=exercise.movement_pattern,
        difficulty=exercise.difficulty,
        is_compound=exercise.is_compound,
        min_reps=exercise.default_min_reps,
        max_reps=exercise.default_max_reps,
        rest_seconds=exercise.default_rest_seconds,
        equipment=[
            ExerciseEquipmentResponse(
                code=item.code,
                name=item.name,
            )
            for item in equipment
        ],
        secondary_muscles=[
            ExerciseSecondaryMuscleResponse(
                code=secondary_muscle.code,
                name=secondary_muscle.name,
                contribution_weight=relation.contribution_weight,
            )
            for relation, secondary_muscle
            in secondary_rows
        ],
    )