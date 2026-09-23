from decimal import Decimal
from types import SimpleNamespace
from uuid import uuid4

from app.services import progress_service


class _Result:
    def __init__(self, rows):
        self._rows = rows

    def all(self):
        return self._rows


class _FakeDb:
    def __init__(self, rows):
        self._rows = rows

    def execute(self, statement):
        return _Result(self._rows)


def test_progress_overview_excludes_exercise_without_logged_sets(
    monkeypatch,
):
    db = _FakeDb(
        [
            (
                "SKIPPED_ONLY",
                "Skipped Only",
            ),
        ]
    )

    user = SimpleNamespace(
        id=uuid4(),
    )

    def no_history(
        db,
        user,
        exercise_code,
    ):
        raise progress_service.ExerciseHistoryNotFoundError(
            "No exercise history found"
        )

    monkeypatch.setattr(
        progress_service,
        "get_exercise_progress_analysis",
        no_history,
    )

    overview = (
        progress_service.get_progress_overview(
            db=db,
            user=user,
        )
    )

    assert overview.total_exercises == 0
    assert overview.improving == 0
    assert overview.stable == 0
    assert overview.declining == 0
    assert overview.insufficient_data == 0
    assert overview.exercises == []


def test_progress_overview_keeps_partial_logged_exercise(
    monkeypatch,
):
    db = _FakeDb(
        [
            (
                "PARTIAL_CURL",
                "Partial Curl",
            ),
        ]
    )

    user = SimpleNamespace(
        id=uuid4(),
    )

    analysis = (
        progress_service.ExerciseProgressAnalysis(
            exercise_code="PARTIAL_CURL",
            exercise_name="Partial Curl",
            history_entries=1,
            completed_sessions=0,
            best_weight_kg=Decimal("16"),
            best_weight_reps=10,
            best_session_volume_kg=Decimal("0"),
            latest_top_weight_kg=None,
            latest_volume_kg=None,
            latest_average_rpe=None,
            previous_top_weight_kg=None,
            previous_volume_kg=None,
            previous_average_rpe=None,
            volume_change_percent=None,
            trend="insufficient_data",
        )
    )

    def partial_history(
        db,
        user,
        exercise_code,
    ):
        return analysis

    monkeypatch.setattr(
        progress_service,
        "get_exercise_progress_analysis",
        partial_history,
    )

    overview = (
        progress_service.get_progress_overview(
            db=db,
            user=user,
        )
    )

    assert overview.total_exercises == 1
    assert overview.insufficient_data == 1

    item = overview.exercises[0]

    assert item.exercise_code == "PARTIAL_CURL"
    assert item.history_entries == 1
    assert item.completed_sessions == 0
    assert item.best_weight_kg == Decimal("16")
    assert item.trend == "insufficient_data"
