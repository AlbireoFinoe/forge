from uuid import UUID

from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    Query,
    status,
)
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.schemas.progress import (
    ExerciseHistoryResponse,
    ExerciseProgressResponse,
    ProgressOverviewItemResponse,
    ProgressOverviewResponse,
    WorkoutProgressResponse,
)
from app.services.progress_service import (
    ExerciseHistoryNotFoundError,
    WorkoutProgressNotFoundError,
    get_exercise_history,
    get_exercise_progress_analysis,
    get_progress_overview,
    get_workout_progress_summary,
)


router = APIRouter(
    prefix="/progress",
    tags=["Progress"],
)


@router.get(
    "/overview",
    response_model=ProgressOverviewResponse,
)
def get_progress_overview_endpoint(
    db: Session = Depends(get_db),
    current_user: User = Depends(
        get_current_user
    ),
):
    overview = get_progress_overview(
        db=db,
        user=current_user,
    )

    exercises = [
        ProgressOverviewItemResponse(
            exercise_code=(
                item.exercise_code
            ),
            exercise_name=(
                item.exercise_name
            ),
            history_entries=(
                item.history_entries
            ),
            completed_sessions=(
                item.completed_sessions
            ),
            best_weight_kg=(
                item.best_weight_kg
            ),
            latest_top_weight_kg=(
                item.latest_top_weight_kg
            ),
            latest_volume_kg=(
                item.latest_volume_kg
            ),
            volume_change_percent=(
                item.volume_change_percent
            ),
            trend=item.trend,
        )
        for item in overview.exercises
    ]

    return ProgressOverviewResponse(
        total_exercises=(
            overview.total_exercises
        ),
        improving=overview.improving,
        stable=overview.stable,
        declining=overview.declining,
        insufficient_data=(
            overview.insufficient_data
        ),
        exercises=exercises,
    )


@router.get(
    "/exercises/{exercise_code}/history",
    response_model=list[
        ExerciseHistoryResponse
    ],
)
def get_exercise_history_endpoint(
    exercise_code: str,
    limit: int = Query(
        default=20,
        ge=1,
        le=100,
    ),
    db: Session = Depends(get_db),
    current_user: User = Depends(
        get_current_user
    ),
):
    history = get_exercise_history(
        db=db,
        user=current_user,
        exercise_code=exercise_code,
        limit=limit,
    )

    return [
        ExerciseHistoryResponse(
            workout_id=item.workout_id,
            workout_completed_at=(
                item.workout_completed_at
            ),
            exercise_code=(
                item.exercise_code
            ),
            exercise_name=(
                item.exercise_name
            ),
            exercise_status=(
                item.exercise_status
            ),
            target_sets=item.target_sets,
            completed_sets=(
                item.completed_sets
            ),
            set_completion_rate=(
                item.set_completion_rate
            ),
            total_reps=item.total_reps,
            top_weight_kg=(
                item.top_weight_kg
            ),
            external_volume_kg=(
                item.external_volume_kg
            ),
            average_rpe=(
                item.average_rpe
            ),
        )
        for item in history
    ]


@router.get(
    "/exercises/{exercise_code}",
    response_model=ExerciseProgressResponse,
)
def get_exercise_progress_endpoint(
    exercise_code: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        get_current_user
    ),
):
    try:
        result = (
            get_exercise_progress_analysis(
                db=db,
                user=current_user,
                exercise_code=exercise_code,
            )
        )

    except ExerciseHistoryNotFoundError as exc:
        raise HTTPException(
            status_code=(
                status.HTTP_404_NOT_FOUND
            ),
            detail=str(exc),
        ) from exc

    return ExerciseProgressResponse(
        exercise_code=(
            result.exercise_code
        ),
        exercise_name=(
            result.exercise_name
        ),
        history_entries=(
            result.history_entries
        ),
        completed_sessions=(
            result.completed_sessions
        ),
        best_weight_kg=(
            result.best_weight_kg
        ),
        best_weight_reps=(
            result.best_weight_reps
        ),
        best_session_volume_kg=(
            result.best_session_volume_kg
        ),
        latest_top_weight_kg=(
            result.latest_top_weight_kg
        ),
        latest_volume_kg=(
            result.latest_volume_kg
        ),
        latest_average_rpe=(
            result.latest_average_rpe
        ),
        previous_top_weight_kg=(
            result.previous_top_weight_kg
        ),
        previous_volume_kg=(
            result.previous_volume_kg
        ),
        previous_average_rpe=(
            result.previous_average_rpe
        ),
        volume_change_percent=(
            result.volume_change_percent
        ),
        trend=result.trend,
    )


@router.get(
    "/workouts/{workout_id}",
    response_model=WorkoutProgressResponse,
)
def get_workout_progress_endpoint(
    workout_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        get_current_user
    ),
):
    try:
        result = (
            get_workout_progress_summary(
                db=db,
                user=current_user,
                workout_session_id=(
                    workout_id
                ),
            )
        )

    except WorkoutProgressNotFoundError as exc:
        raise HTTPException(
            status_code=(
                status.HTTP_404_NOT_FOUND
            ),
            detail=str(exc),
        ) from exc

    return WorkoutProgressResponse(
        workout_id=result.workout_id,
        program_version_number=(
            result.program_version_number
        ),
        day_name=result.day_name,
        status=result.status,
        started_at=result.started_at,
        completed_at=result.completed_at,
        duration_minutes=(
            result.duration_minutes
        ),
        total_exercises=(
            result.total_exercises
        ),
        completed_exercises=(
            result.completed_exercises
        ),
        skipped_exercises=(
            result.skipped_exercises
        ),
        planned_sets=result.planned_sets,
        completed_sets=(
            result.completed_sets
        ),
        set_completion_rate=(
            result.set_completion_rate
        ),
        total_reps=result.total_reps,
        external_volume_kg=(
            result.external_volume_kg
        ),
        average_rpe=result.average_rpe,
    )