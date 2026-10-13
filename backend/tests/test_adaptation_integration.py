"""Integration tests for load resolution wired into adaptation service.

Tests cover:
- PROGRESS_LOAD resolves achievable weight (rounds UP to increment)
- REDUCE_STRESS resolves achievable weight (rounds DOWN to increment)
- Fractional increment (0.5 kg)
- Missing load preference -> achievable_weight_kg is None
- Missing latest weight -> achievable_weight_kg is None
- User isolation: preference of user A does not bleed into user B
- No exercise history fallback
"""
from decimal import Decimal
from types import SimpleNamespace
from uuid import uuid4

from app.services import adaptation_service
from app.services.progress_service import (
    ExerciseProgressAnalysis,
    ExerciseHistoryNotFoundError,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_user():
    return SimpleNamespace(id=uuid4())


def _make_analysis(
    *,
    exercise_code="BENCH_PRESS",
    exercise_name="Bench Press",
    completed_sessions=3,
    trend="improving",
    latest_top_weight_kg=Decimal("80"),
    latest_average_rpe=Decimal("8.5"),
):
    return ExerciseProgressAnalysis(
        exercise_code=exercise_code,
        exercise_name=exercise_name,
        history_entries=3,
        completed_sessions=completed_sessions,
        best_weight_kg=latest_top_weight_kg,
        best_weight_reps=8,
        best_session_volume_kg=Decimal("960"),
        latest_top_weight_kg=latest_top_weight_kg,
        latest_volume_kg=Decimal("960"),
        latest_average_rpe=latest_average_rpe,
        previous_top_weight_kg=Decimal("77.5"),
        previous_volume_kg=Decimal("930"),
        previous_average_rpe=Decimal("8.0"),
        volume_change_percent=3.2,
        trend=trend,
    )


def _patch_analysis(monkeypatch, analysis_or_exc):
    if isinstance(analysis_or_exc, BaseException):
        exc = analysis_or_exc

        def _raise(*args, **kwargs):
            raise exc

        monkeypatch.setattr(
            adaptation_service,
            "get_exercise_progress_analysis",
            _raise,
        )
    else:
        monkeypatch.setattr(
            adaptation_service,
            "get_exercise_progress_analysis",
            lambda *a, **kw: analysis_or_exc,
        )


class _FakeExecResult:
    def __init__(self, increment_kg):
        self._increment_kg = increment_kg

    def one_or_none(self):
        if self._increment_kg is None:
            return None
        return (self._increment_kg,)


class _FakeDb:
    """Configurable fake DB supporting scalar() and execute().one_or_none()."""

    def __init__(self, scalar_result=None, increment_kg=None):
        self._scalar_result = scalar_result
        self._increment_kg = increment_kg

    def scalar(self, stmt):
        return self._scalar_result

    def execute(self, stmt):
        return _FakeExecResult(self._increment_kg)


# ---------------------------------------------------------------------------
# Tests for _get_increment_for_exercise
# ---------------------------------------------------------------------------


def test_get_increment_returns_none_when_no_preference():
    db = _FakeDb(increment_kg=None)
    user = _make_user()

    result = adaptation_service._get_increment_for_exercise(
        db=db,
        user=user,
        exercise_code="BENCH_PRESS",
    )

    assert result is None


def test_get_increment_returns_value_when_preference_exists():
    db = _FakeDb(increment_kg=Decimal("2.5"))
    user = _make_user()

    result = adaptation_service._get_increment_for_exercise(
        db=db,
        user=user,
        exercise_code="BENCH_PRESS",
    )

    assert result == Decimal("2.5")


# ---------------------------------------------------------------------------
# Tests for get_exercise_adaptation_recommendation
# ---------------------------------------------------------------------------


def test_progress_load_achievable_weight_rounds_up(monkeypatch):
    """2.5% increase on 80 kg = 82.0 kg. With 2.5-kg increment -> 82.5 kg."""
    _patch_analysis(monkeypatch, _make_analysis(
        trend="improving",
        latest_top_weight_kg=Decimal("80"),
        latest_average_rpe=Decimal("8.5"),
        completed_sessions=3,
    ))

    exercise = SimpleNamespace(name="Bench Press")
    db = _FakeDb(scalar_result=exercise, increment_kg=Decimal("2.5"))

    result = adaptation_service.get_exercise_adaptation_recommendation(
        db=db,
        user=_make_user(),
        exercise_code="BENCH_PRESS",
    )

    assert result.action == "PROGRESS_LOAD"
    assert result.suggested_load_change_percent == 2.5
    # raw = 80 * 1.025 = 82.0 -> ceil(82.0/2.5)*2.5 = 82.5
    assert result.achievable_weight_kg == Decimal("82.5")


def test_reduce_stress_achievable_weight_rounds_down(monkeypatch):
    """-5% on 100 kg = 95.0 kg. With 2.5-kg increment -> floor(95/2.5)*2.5 = 95.0 kg."""
    _patch_analysis(monkeypatch, _make_analysis(
        trend="declining",
        latest_top_weight_kg=Decimal("100"),
        latest_average_rpe=Decimal("9.0"),
        completed_sessions=3,
    ))

    exercise = SimpleNamespace(name="Squat")
    db = _FakeDb(scalar_result=exercise, increment_kg=Decimal("2.5"))

    result = adaptation_service.get_exercise_adaptation_recommendation(
        db=db,
        user=_make_user(),
        exercise_code="SQUAT",
    )

    assert result.action == "REDUCE_STRESS"
    assert result.suggested_load_change_percent == -5.0
    # raw = 100 * 0.95 = 95.0 -> floor(95.0/2.5)*2.5 = 95.0
    assert result.achievable_weight_kg == Decimal("95.0")


def test_fractional_increment_supported(monkeypatch):
    """20 kg + 2.5% = 20.5 kg; 0.5-kg increment -> 20.5 (exact)."""
    _patch_analysis(monkeypatch, _make_analysis(
        trend="improving",
        latest_top_weight_kg=Decimal("20"),
        latest_average_rpe=Decimal("8.0"),
        completed_sessions=3,
    ))

    exercise = SimpleNamespace(name="Dumbbell Curl")
    db = _FakeDb(scalar_result=exercise, increment_kg=Decimal("0.5"))

    result = adaptation_service.get_exercise_adaptation_recommendation(
        db=db,
        user=_make_user(),
        exercise_code="DB_CURL",
    )

    assert result.action == "PROGRESS_LOAD"
    assert result.achievable_weight_kg == Decimal("20.5")


def test_missing_increment_preference_yields_no_achievable_weight(monkeypatch):
    """When user has no load preference for the exercise, achievable_weight_kg is None."""
    _patch_analysis(monkeypatch, _make_analysis(
        trend="improving",
        latest_top_weight_kg=Decimal("80"),
        latest_average_rpe=Decimal("8.5"),
        completed_sessions=3,
    ))

    exercise = SimpleNamespace(name="Bench Press")
    db = _FakeDb(scalar_result=exercise, increment_kg=None)

    result = adaptation_service.get_exercise_adaptation_recommendation(
        db=db,
        user=_make_user(),
        exercise_code="BENCH_PRESS",
    )

    assert result.action == "PROGRESS_LOAD"
    assert result.achievable_weight_kg is None


def test_missing_latest_weight_yields_no_achievable_weight(monkeypatch):
    """Bodyweight exercise has no weight; achievable_weight_kg must be None."""
    _patch_analysis(monkeypatch, _make_analysis(
        trend="improving",
        latest_top_weight_kg=None,
        latest_average_rpe=Decimal("8.0"),
        completed_sessions=3,
    ))

    exercise = SimpleNamespace(name="Push-Up")
    db = _FakeDb(scalar_result=exercise, increment_kg=Decimal("1"))

    result = adaptation_service.get_exercise_adaptation_recommendation(
        db=db,
        user=_make_user(),
        exercise_code="PUSH_UP",
    )

    # bodyweight + improving -> PROGRESS_REPS (no external load)
    assert result.action == "PROGRESS_REPS"
    assert result.achievable_weight_kg is None


def test_user_isolation_different_increments(monkeypatch):
    """Two users with different increments get independent achievable weights."""
    _patch_analysis(monkeypatch, _make_analysis(
        trend="improving",
        latest_top_weight_kg=Decimal("80"),
        latest_average_rpe=Decimal("8.5"),
        completed_sessions=3,
    ))

    exercise = SimpleNamespace(name="Bench Press")

    db_a = _FakeDb(scalar_result=exercise, increment_kg=Decimal("2.5"))
    result_a = adaptation_service.get_exercise_adaptation_recommendation(
        db=db_a,
        user=_make_user(),
        exercise_code="BENCH_PRESS",
    )

    db_b = _FakeDb(scalar_result=exercise, increment_kg=Decimal("5"))
    result_b = adaptation_service.get_exercise_adaptation_recommendation(
        db=db_b,
        user=_make_user(),
        exercise_code="BENCH_PRESS",
    )

    # 80 * 1.025 = 82.0 -> ceil(82.0/2.5)*2.5 = 82.5 for user A
    assert result_a.achievable_weight_kg == Decimal("82.5")
    # 80 * 1.025 = 82.0 -> ceil(82.0/5)*5 = 85.0 for user B
    assert result_b.achievable_weight_kg == Decimal("85.0")


def test_no_history_yields_no_achievable_weight(monkeypatch):
    """When exercise has no history, achievable_weight_kg is None."""
    _patch_analysis(
        monkeypatch,
        ExerciseHistoryNotFoundError("no history"),
    )

    exercise = SimpleNamespace(name="Bench Press")
    db = _FakeDb(scalar_result=exercise, increment_kg=Decimal("2.5"))

    result = adaptation_service.get_exercise_adaptation_recommendation(
        db=db,
        user=_make_user(),
        exercise_code="BENCH_PRESS",
    )

    assert result.action == "KEEP_CURRENT"
    assert result.achievable_weight_kg is None
