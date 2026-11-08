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
from app.schemas.adaptation import (
    AdaptationOverviewResponse,
    AdaptationRecommendationResponse,
)
from app.services.adaptation_service import (
    ExerciseNotFoundError,
    get_adaptation_overview,
    get_exercise_adaptation_recommendation,
)


router = APIRouter(
    prefix="/adaptation",
    tags=["Adaptation"],
)


def _build_recommendation_response(
    recommendation,
) -> AdaptationRecommendationResponse:
    return AdaptationRecommendationResponse(
        exercise_code=(
            recommendation.exercise_code
        ),
        exercise_name=(
            recommendation.exercise_name
        ),
        action=recommendation.action,
        confidence=(
            recommendation.confidence
        ),
        reason_codes=(
            recommendation.reason_codes
        ),
        completed_sessions=(
            recommendation.completed_sessions
        ),
        trend=recommendation.trend,
        latest_weight_kg=(
            recommendation.latest_weight_kg
        ),
        latest_average_rpe=(
            recommendation.latest_average_rpe
        ),
        volume_change_percent=(
            recommendation.volume_change_percent
        ),
        suggested_load_change_percent=(
            recommendation
            .suggested_load_change_percent
        ),
        suggested_rep_change=(
            recommendation.suggested_rep_change
        ),
        suggested_set_change=(
            recommendation.suggested_set_change
        ),
    )


@router.get(
    "/overview",
    response_model=AdaptationOverviewResponse,
)
def get_adaptation_overview_endpoint(
    db: Session = Depends(get_db),
    current_user: User = Depends(
        get_current_user
    ),
):
    overview = get_adaptation_overview(
        db=db,
        user=current_user,
    )

    return AdaptationOverviewResponse(
        total_exercises=(
            overview.total_exercises
        ),
        progress_load=(
            overview.progress_load
        ),
        progress_reps=(
            overview.progress_reps
        ),
        hold_load=overview.hold_load,
        keep_current=(
            overview.keep_current
        ),
        reduce_stress=(
            overview.reduce_stress
        ),
        recommendations=[
            _build_recommendation_response(
                recommendation
            )
            for recommendation
            in overview.recommendations
        ],
    )


@router.get(
    "/exercises/{exercise_code}",
    response_model=(
        AdaptationRecommendationResponse
    ),
)
def get_exercise_adaptation_endpoint(
    exercise_code: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        get_current_user
    ),
):
    try:
        recommendation = (
            get_exercise_adaptation_recommendation(
                db=db,
                user=current_user,
                exercise_code=exercise_code,
            )
        )

    except ExerciseNotFoundError as exc:
        raise HTTPException(
            status_code=(
                status.HTTP_404_NOT_FOUND
            ),
            detail=str(exc),
        ) from exc

    return _build_recommendation_response(
        recommendation
    )