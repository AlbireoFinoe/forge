from uuid import UUID

from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    status,
)
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.schemas.workout import (
    WorkoutExerciseResponse,
    WorkoutSessionResponse,
    WorkoutSetLogRequest,
    WorkoutSetResponse,
    WorkoutStartRequest,
    WorkoutSummaryResponse,
)
from app.services.workout_service import (
    EmptyProgramDayError,
    ProgramDayNotFoundError,
    WorkoutAlreadyInProgressError,
    WorkoutExerciseAlreadyCompletedError,
    WorkoutExerciseNotFoundError,
    WorkoutExerciseSkippedError,
    WorkoutHasPendingExercisesError,
    WorkoutNotInProgressError,
    WorkoutSetNotFoundError,
    WorkoutSetValidationError,
    WorkoutSessionNotFoundError,
    finish_workout,
    get_in_progress_workout,
    get_user_workout_history,
    get_workout_by_id,
    get_workout_exercises,
    get_workout_sets,
    log_workout_set,
    skip_workout_exercise,
    start_workout,
)


router = APIRouter(
    prefix="/workouts",
    tags=["Workouts"],
)


def _build_set_response(
    workout_set,
) -> WorkoutSetResponse:
    return WorkoutSetResponse(
        id=workout_set.id,
        set_number=workout_set.set_number,
        actual_reps=workout_set.actual_reps,
        weight_kg=workout_set.weight_kg,
        rpe=workout_set.rpe,
        is_completed=workout_set.is_completed,
        completed_at=workout_set.completed_at,
    )


def _build_exercise_response(
    db: Session,
    exercise,
) -> WorkoutExerciseResponse:
    sets = get_workout_sets(
        db,
        exercise.id,
    )

    return WorkoutExerciseResponse(
        id=exercise.id,
        program_exercise_id=(
            exercise.program_exercise_id
        ),
        exercise_id=exercise.exercise_id,
        exercise_code=exercise.exercise_code,
        exercise_name=exercise.exercise_name,
        exercise_order=exercise.exercise_order,
        target_sets=exercise.target_sets,
        target_min_reps=(
            exercise.target_min_reps
        ),
        target_max_reps=(
            exercise.target_max_reps
        ),
        target_rest_seconds=(
            exercise.target_rest_seconds
        ),
        status=exercise.status,
        notes=exercise.notes,
        sets=[
            _build_set_response(
                workout_set
            )
            for workout_set in sets
        ],
    )


def _build_session_response(
    db: Session,
    workout,
) -> WorkoutSessionResponse:
    exercises = get_workout_exercises(
        db,
        workout.id,
    )

    return WorkoutSessionResponse(
        id=workout.id,
        training_program_id=(
            workout.training_program_id
        ),
        program_day_id=workout.program_day_id,
        program_version_number=(
            workout.program_version_number
        ),
        program_name=workout.program_name,
        day_name=workout.day_name,
        day_of_week=workout.day_of_week,
        day_order=workout.day_order,
        status=workout.status,
        notes=workout.notes,
        started_at=workout.started_at,
        completed_at=workout.completed_at,
        created_at=workout.created_at,
        exercises=[
            _build_exercise_response(
                db,
                exercise,
            )
            for exercise in exercises
        ],
    )


@router.post(
    "/start",
    response_model=WorkoutSessionResponse,
    status_code=status.HTTP_201_CREATED,
)
def start_workout_endpoint(
    payload: WorkoutStartRequest,
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(get_db),
):
    try:
        workout = start_workout(
            db=db,
            user=current_user,
            program_day_id=(
                payload.program_day_id
            ),
        )

    except WorkoutAlreadyInProgressError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc

    except ProgramDayNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc

    except EmptyProgramDayError as exc:
        raise HTTPException(
            status_code=(
                status.HTTP_422_UNPROCESSABLE_ENTITY
            ),
            detail=str(exc),
        ) from exc

    return _build_session_response(
        db,
        workout,
    )


@router.get(
    "/current",
    response_model=WorkoutSessionResponse,
)
def get_current_workout_endpoint(
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(get_db),
):
    workout = get_in_progress_workout(
        db,
        current_user,
    )

    if workout is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No workout in progress",
        )

    return _build_session_response(
        db,
        workout,
    )


@router.get(
    "/history",
    response_model=list[
        WorkoutSummaryResponse
    ],
)
def get_workout_history_endpoint(
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(get_db),
):
    workouts = get_user_workout_history(
        db,
        current_user,
    )

    return [
        WorkoutSummaryResponse(
            id=workout.id,
            program_version_number=(
                workout.program_version_number
            ),
            program_name=workout.program_name,
            day_name=workout.day_name,
            day_of_week=workout.day_of_week,
            day_order=workout.day_order,
            status=workout.status,
            started_at=workout.started_at,
            completed_at=workout.completed_at,
        )
        for workout in workouts
    ]


@router.patch(
    "/sets/{workout_set_id}",
    response_model=WorkoutSetResponse,
)
def log_workout_set_endpoint(
    workout_set_id: UUID,
    payload: WorkoutSetLogRequest,
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(get_db),
):
    try:
        workout_set = log_workout_set(
            db=db,
            user=current_user,
            workout_set_id=workout_set_id,
            actual_reps=payload.actual_reps,
            weight_kg=payload.weight_kg,
            rpe=payload.rpe,
        )

    except WorkoutSetNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc

    except (
        WorkoutNotInProgressError,
        WorkoutExerciseSkippedError,
        WorkoutSetValidationError,
    ) as exc:
        raise HTTPException(
            status_code=(
                status.HTTP_422_UNPROCESSABLE_ENTITY
            ),
            detail=str(exc),
        ) from exc

    return _build_set_response(
        workout_set
    )


@router.post(
    "/exercises/{workout_exercise_id}/skip",
    response_model=WorkoutExerciseResponse,
)
def skip_workout_exercise_endpoint(
    workout_exercise_id: UUID,
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(get_db),
):
    try:
        exercise = skip_workout_exercise(
            db=db,
            user=current_user,
            workout_exercise_id=(
                workout_exercise_id
            ),
        )

    except WorkoutExerciseNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc

    except (
        WorkoutNotInProgressError,
        WorkoutExerciseAlreadyCompletedError,
    ) as exc:
        raise HTTPException(
            status_code=(
                status.HTTP_422_UNPROCESSABLE_ENTITY
            ),
            detail=str(exc),
        ) from exc

    return _build_exercise_response(
        db,
        exercise,
    )


@router.post(
    "/{workout_id}/finish",
    response_model=WorkoutSessionResponse,
)
def finish_workout_endpoint(
    workout_id: UUID,
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(get_db),
):
    try:
        workout = finish_workout(
            db=db,
            user=current_user,
            workout_session_id=workout_id,
        )

    except WorkoutHasPendingExercisesError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc

    except WorkoutNotInProgressError as exc:
        raise HTTPException(
            status_code=(
                status.HTTP_422_UNPROCESSABLE_ENTITY
            ),
            detail=str(exc),
        ) from exc

    except WorkoutSessionNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc

    return _build_session_response(
        db,
        workout,
    )


@router.get(
    "/{workout_id}",
    response_model=WorkoutSessionResponse,
)
def get_workout_by_id_endpoint(
    workout_id: UUID,
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(get_db),
):
    workout = get_workout_by_id(
        db,
        current_user,
        workout_id,
    )

    if workout is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Workout not found",
        )

    return _build_session_response(
        db,
        workout,
    )