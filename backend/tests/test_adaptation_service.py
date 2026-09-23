from decimal import Decimal

from app.services.adaptation_service import (
    decide_adaptation,
)


def test_insufficient_sessions_keeps_current():
    result = decide_adaptation(
        completed_sessions=1,
        trend="improving",
        latest_weight_kg=Decimal("80"),
        latest_average_rpe=Decimal("7.5"),
    )

    assert result.action == "KEEP_CURRENT"
    assert result.confidence == "low"
    assert result.reason_codes == [
        "INSUFFICIENT_COMPLETED_SESSIONS"
    ]


def test_missing_rpe_keeps_current():
    result = decide_adaptation(
        completed_sessions=3,
        trend="improving",
        latest_weight_kg=Decimal("80"),
        latest_average_rpe=None,
    )

    assert result.action == "KEEP_CURRENT"
    assert result.confidence == "low"
    assert result.reason_codes == [
        "MISSING_RPE_DATA"
    ]


def test_improving_weighted_progresses_load():
    result = decide_adaptation(
        completed_sessions=3,
        trend="improving",
        latest_weight_kg=Decimal("80"),
        latest_average_rpe=Decimal("8.5"),
    )

    assert result.action == "PROGRESS_LOAD"
    assert result.confidence == "high"
    assert (
        result.suggested_load_change_percent
        == 2.5
    )
    assert result.suggested_rep_change is None
    assert result.suggested_set_change is None


def test_improving_bodyweight_progresses_reps():
    result = decide_adaptation(
        completed_sessions=3,
        trend="improving",
        latest_weight_kg=None,
        latest_average_rpe=Decimal("8.0"),
    )

    assert result.action == "PROGRESS_REPS"
    assert result.confidence == "medium"
    assert result.suggested_rep_change == 1


def test_improving_high_rpe_holds_load():
    result = decide_adaptation(
        completed_sessions=3,
        trend="improving",
        latest_weight_kg=Decimal("80"),
        latest_average_rpe=Decimal("9.5"),
    )

    assert result.action == "HOLD_LOAD"
    assert result.confidence == "medium"
    assert "RPE_HIGH" in result.reason_codes


def test_stable_low_rpe_progresses_reps():
    result = decide_adaptation(
        completed_sessions=3,
        trend="stable",
        latest_weight_kg=Decimal("80"),
        latest_average_rpe=Decimal("8.0"),
    )

    assert result.action == "PROGRESS_REPS"
    assert result.suggested_rep_change == 1


def test_stable_higher_rpe_keeps_current():
    result = decide_adaptation(
        completed_sessions=3,
        trend="stable",
        latest_weight_kg=Decimal("80"),
        latest_average_rpe=Decimal("8.5"),
    )

    assert result.action == "KEEP_CURRENT"
    assert result.confidence == "medium"


def test_declining_high_rpe_reduces_stress():
    result = decide_adaptation(
        completed_sessions=3,
        trend="declining",
        latest_weight_kg=Decimal("80"),
        latest_average_rpe=Decimal("9.0"),
    )

    assert result.action == "REDUCE_STRESS"
    assert result.confidence == "medium"
    assert (
        result.suggested_load_change_percent
        == -5.0
    )
    assert result.suggested_rep_change is None
    assert result.suggested_set_change == -1


def test_declining_without_high_rpe_keeps_current():
    result = decide_adaptation(
        completed_sessions=3,
        trend="declining",
        latest_weight_kg=Decimal("80"),
        latest_average_rpe=Decimal("8.0"),
    )

    assert result.action == "KEEP_CURRENT"
    assert "REVIEW_BEFORE_REDUCTION" in (
        result.reason_codes
    )


def test_unknown_trend_keeps_current():
    result = decide_adaptation(
        completed_sessions=3,
        trend="insufficient_data",
        latest_weight_kg=Decimal("80"),
        latest_average_rpe=Decimal("8.0"),
    )

    assert result.action == "KEEP_CURRENT"
    assert result.confidence == "low"
    assert result.reason_codes == [
        "INSUFFICIENT_DATA"
    ]
