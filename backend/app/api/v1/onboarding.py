from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.schemas.onboarding import (
    GoalResponse,
    GoalUpdate,
    OnboardingResponse,
    TrainingPreferencesResponse,
    TrainingPreferencesUpdate,
)
from app.services.onboarding import (
    get_goal,
    get_training_days,
    get_training_preferences,
    set_goal,
    set_training_preferences,
)


router = APIRouter(
    prefix="/onboarding",
    tags=["Onboarding"],
)


@router.put(
    "/goal",
    response_model=GoalResponse,
)
def update_goal(
    payload: GoalUpdate,
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(get_db),
):
    return set_goal(
        db,
        current_user,
        payload,
    )


@router.put(
    "/training-preferences",
    response_model=TrainingPreferencesResponse,
)
def update_training_preferences(
    payload: TrainingPreferencesUpdate,
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(get_db),
):
    preferences = set_training_preferences(
        db,
        current_user,
        payload,
    )

    return TrainingPreferencesResponse(
        id=preferences.id,
        user_id=preferences.user_id,
        days_per_week=preferences.days_per_week,
        session_duration_minutes=(
            preferences.session_duration_minutes
        ),
        available_days=get_training_days(
            db,
            current_user,
        ),
        no_dedicated_leg_day=(
            preferences.no_dedicated_leg_day
        ),
        arm_specialization=(
            preferences.arm_specialization
        ),
        created_at=preferences.created_at,
        updated_at=preferences.updated_at,
    )


@router.get(
    "",
    response_model=OnboardingResponse,
)
def get_onboarding(
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(get_db),
):
    goal = get_goal(
        db,
        current_user,
    )

    preferences = get_training_preferences(
        db,
        current_user,
    )

    training_response = None

    if preferences is not None:
        training_response = TrainingPreferencesResponse(
            id=preferences.id,
            user_id=preferences.user_id,
            days_per_week=preferences.days_per_week,
            session_duration_minutes=(
                preferences.session_duration_minutes
            ),
            available_days=get_training_days(
                db,
                current_user,
            ),
            no_dedicated_leg_day=(
                preferences.no_dedicated_leg_day
            ),
            arm_specialization=(
                preferences.arm_specialization
            ),
            created_at=preferences.created_at,
            updated_at=preferences.updated_at,
        )

    return OnboardingResponse(
        goal=goal,
        training_preferences=training_response,
    )