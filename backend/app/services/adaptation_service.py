from dataclasses import dataclass
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.equipment import Equipment
from app.models.exercise import Exercise
from app.models.exercise_equipment import ExerciseEquipment
from app.models.user import User
from app.models.user_load_preference import UserLoadPreference
from app.services.load_resolution_service import (
    LoadResolution,
    resolve_achievable_load,
)
from app.services.progress_service import (
    ExerciseHistoryNotFoundError,
    get_exercise_progress_analysis,
    get_progress_overview,
)


class AdaptationError(Exception):
    pass


class ExerciseNotFoundError(AdaptationError):
    pass


@dataclass(frozen=True)
class AdaptationDecision:
    action: str
    confidence: str

    reason_codes: list[str]

    suggested_load_change_percent: float | None
    suggested_rep_change: int | None
    suggested_set_change: int | None


@dataclass(frozen=True)
class ExerciseAdaptationRecommendation:
    exercise_code: str
    exercise_name: str | None

    action: str
    confidence: str

    reason_codes: list[str]

    completed_sessions: int
    trend: str

    latest_weight_kg: Decimal | None
    latest_average_rpe: Decimal | None
    volume_change_percent: float | None

    suggested_load_change_percent: float | None
    suggested_rep_change: int | None
    suggested_set_change: int | None

    achievable_weight_kg: Decimal | None

@dataclass(frozen=True)
class AdaptationOverview:
    total_exercises: int

    progress_load: int
    progress_reps: int
    hold_load: int
    keep_current: int
    reduce_stress: int

    recommendations: list[
        ExerciseAdaptationRecommendation
    ]


def decide_adaptation(
    completed_sessions: int,
    trend: str,
    latest_weight_kg: Decimal | None,
    latest_average_rpe: Decimal | None,
) -> AdaptationDecision:

    if completed_sessions < 2:
        return AdaptationDecision(
            action="KEEP_CURRENT",
            confidence="low",
            reason_codes=[
                "INSUFFICIENT_COMPLETED_SESSIONS",
            ],
            suggested_load_change_percent=None,
            suggested_rep_change=None,
            suggested_set_change=None,
        )

    if latest_average_rpe is None:
        return AdaptationDecision(
            action="KEEP_CURRENT",
            confidence="low",
            reason_codes=[
                "MISSING_RPE_DATA",
            ],
            suggested_load_change_percent=None,
            suggested_rep_change=None,
            suggested_set_change=None,
        )

    rpe = latest_average_rpe

    if trend == "improving":

        if (
            latest_weight_kg is not None
            and rpe <= Decimal("9.0")
        ):
            return AdaptationDecision(
                action="PROGRESS_LOAD",
                confidence="high",
                reason_codes=[
                    "PERFORMANCE_IMPROVING",
                    "RPE_MANAGEABLE",
                ],
                suggested_load_change_percent=2.5,
                suggested_rep_change=None,
                suggested_set_change=None,
            )

        if (
            latest_weight_kg is None
            and rpe <= Decimal("9.0")
        ):
            return AdaptationDecision(
                action="PROGRESS_REPS",
                confidence="medium",
                reason_codes=[
                    "PERFORMANCE_IMPROVING",
                    "NO_EXTERNAL_LOAD",
                ],
                suggested_load_change_percent=None,
                suggested_rep_change=1,
                suggested_set_change=None,
            )

        return AdaptationDecision(
            action="HOLD_LOAD",
            confidence="medium",
            reason_codes=[
                "PERFORMANCE_IMPROVING",
                "RPE_HIGH",
            ],
            suggested_load_change_percent=None,
            suggested_rep_change=None,
            suggested_set_change=None,
        )

    if trend == "stable":

        if rpe <= Decimal("8.0"):
            return AdaptationDecision(
                action="PROGRESS_REPS",
                confidence="medium",
                reason_codes=[
                    "PERFORMANCE_STABLE",
                    "RPE_LOW",
                ],
                suggested_load_change_percent=None,
                suggested_rep_change=1,
                suggested_set_change=None,
            )

        return AdaptationDecision(
            action="KEEP_CURRENT",
            confidence="medium",
            reason_codes=[
                "PERFORMANCE_STABLE",
                "RPE_MODERATE_OR_HIGH",
            ],
            suggested_load_change_percent=None,
            suggested_rep_change=None,
            suggested_set_change=None,
        )

    if trend == "declining":

        if rpe >= Decimal("9.0"):
            return AdaptationDecision(
                action="REDUCE_STRESS",
                confidence="medium",
                reason_codes=[
                    "PERFORMANCE_DECLINING",
                    "RPE_HIGH",
                ],
                suggested_load_change_percent=-5.0,
                suggested_rep_change=None,
                suggested_set_change=-1,
            )

        return AdaptationDecision(
            action="KEEP_CURRENT",
            confidence="medium",
            reason_codes=[
                "PERFORMANCE_DECLINING",
                "REVIEW_BEFORE_REDUCTION",
            ],
            suggested_load_change_percent=None,
            suggested_rep_change=None,
            suggested_set_change=None,
        )

    return AdaptationDecision(
        action="KEEP_CURRENT",
        confidence="low",
        reason_codes=[
            "INSUFFICIENT_DATA",
        ],
        suggested_load_change_percent=None,
        suggested_rep_change=None,
        suggested_set_change=None,
    )


def _get_increment_for_exercise(
    db: Session,
    user: User,
    exercise_code: str,
) -> Decimal | None:
    """
    Return the user's load increment (kg) for the first equipment
    associated with the given exercise for which the user has a
    preference configured.  Returns None when no preference is found.
    """
    row = db.execute(
        select(UserLoadPreference.increment_kg)
        .join(
            ExerciseEquipment,
            ExerciseEquipment.equipment_id
            == UserLoadPreference.equipment_id,
        )
        .join(
            Exercise,
            Exercise.id == ExerciseEquipment.exercise_id,
        )
        .where(
            UserLoadPreference.user_id == user.id,
            Exercise.code == exercise_code,
        )
        .order_by(UserLoadPreference.increment_kg)
        .limit(1)
    ).one_or_none()

    if row is None:
        return None

    return row[0]


def get_exercise_adaptation_recommendation(
    db: Session,
    user: User,
    exercise_code: str,
) -> ExerciseAdaptationRecommendation:
    exercise = db.scalar(
        select(
            Exercise
        ).where(
            Exercise.code
            == exercise_code
        )
    )

    if exercise is None:
        raise ExerciseNotFoundError(
            "Exercise not found"
        )

    try:
        analysis = (
            get_exercise_progress_analysis(
                db=db,
                user=user,
                exercise_code=exercise_code,
            )
        )

    except ExerciseHistoryNotFoundError:
        return ExerciseAdaptationRecommendation(
            exercise_code=exercise_code,
            exercise_name=exercise.name,
            action="KEEP_CURRENT",
            confidence="low",
            reason_codes=[
                "INSUFFICIENT_DATA",
            ],
            completed_sessions=0,
            trend="insufficient_data",
            latest_weight_kg=None,
            latest_average_rpe=None,
            volume_change_percent=None,
            suggested_load_change_percent=None,
            suggested_rep_change=None,
            suggested_set_change=None,
            achievable_weight_kg=None,
        )

    decision = decide_adaptation(
        completed_sessions=(
            analysis.completed_sessions
        ),
        trend=analysis.trend,
        latest_weight_kg=(
            analysis.latest_top_weight_kg
        ),
        latest_average_rpe=(
            analysis.latest_average_rpe
        ),
    )

    increment_kg = _get_increment_for_exercise(
        db=db,
        user=user,
        exercise_code=exercise_code,
    )

    resolution: LoadResolution | None = (
        resolve_achievable_load(
            latest_weight_kg=(
                analysis.latest_top_weight_kg
            ),
            suggested_load_change_percent=(
                decision.suggested_load_change_percent
            ),
            increment_kg=increment_kg,
        )
    )

    return ExerciseAdaptationRecommendation(
        exercise_code=(
            analysis.exercise_code
        ),
        exercise_name=(
            analysis.exercise_name
        ),
        action=decision.action,
        confidence=decision.confidence,
        reason_codes=(
            decision.reason_codes
        ),
        completed_sessions=(
            analysis.completed_sessions
        ),
        trend=analysis.trend,
        latest_weight_kg=(
            analysis.latest_top_weight_kg
        ),
        latest_average_rpe=(
            analysis.latest_average_rpe
        ),
        volume_change_percent=(
            analysis.volume_change_percent
        ),
        suggested_load_change_percent=(
            decision.suggested_load_change_percent
        ),
        suggested_rep_change=(
            decision.suggested_rep_change
        ),
        suggested_set_change=(
            decision.suggested_set_change
        ),
        achievable_weight_kg=(
            resolution.achievable_weight_kg
            if resolution is not None
            else None
        ),
    )
def get_adaptation_overview(
    db: Session,
    user: User,
) -> AdaptationOverview:

    progress_overview = (
        get_progress_overview(
            db=db,
            user=user,
        )
    )

    recommendations = []

    for item in progress_overview.exercises:
        recommendation = (
            get_exercise_adaptation_recommendation(
                db=db,
                user=user,
                exercise_code=(
                    item.exercise_code
                ),
            )
        )

        recommendations.append(
            recommendation
        )

    action_order = {
        "REDUCE_STRESS": 0,
        "PROGRESS_LOAD": 1,
        "PROGRESS_REPS": 2,
        "HOLD_LOAD": 3,
        "KEEP_CURRENT": 4,
    }

    recommendations.sort(
        key=lambda item: (
            action_order.get(
                item.action,
                99,
            ),
            (
                item.exercise_name
                or item.exercise_code
            ).lower(),
        )
    )

    return AdaptationOverview(
        total_exercises=len(
            recommendations
        ),
        progress_load=sum(
            1
            for item in recommendations
            if item.action
            == "PROGRESS_LOAD"
        ),
        progress_reps=sum(
            1
            for item in recommendations
            if item.action
            == "PROGRESS_REPS"
        ),
        hold_load=sum(
            1
            for item in recommendations
            if item.action
            == "HOLD_LOAD"
        ),
        keep_current=sum(
            1
            for item in recommendations
            if item.action
            == "KEEP_CURRENT"
        ),
        reduce_stress=sum(
            1
            for item in recommendations
            if item.action
            == "REDUCE_STRESS"
        ),
        recommendations=(
            recommendations
        ),
    )
