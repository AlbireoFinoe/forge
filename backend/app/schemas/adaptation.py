from decimal import Decimal

from pydantic import BaseModel


class AdaptationRecommendationResponse(BaseModel):
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


class AdaptationOverviewResponse(BaseModel):
    total_exercises: int

    progress_load: int
    progress_reps: int
    hold_load: int
    keep_current: int
    reduce_stress: int

    recommendations: list[
        AdaptationRecommendationResponse
    ]