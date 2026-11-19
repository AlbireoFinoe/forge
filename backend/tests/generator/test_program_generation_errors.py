from dataclasses import replace
from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import Mock, call, create_autospec
from uuid import UUID

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy.exc import OperationalError
from sqlalchemy.orm import Session

from app.api.v1 import programs
from app.generator import builder
from app.generator.context import GeneratorContext, SportContext
from app.generator.distribution import VolumeDistributionError
from app.generator.exercise_pool import ExerciseCandidate
from app.generator.split import SplitEngineError
from app.generator.volume import VolumeEngineError


GENERATE_URL = "/api/v1/programs/generate"


@pytest.fixture
def generation(monkeypatch):
    user = SimpleNamespace(id=UUID(int=1), training_setup_revision=2)
    active_program = SimpleNamespace(status="active", version_number=1)
    db = create_autospec(Session, instance=True, spec_set=True)
    db.scalar.return_value = active_program.version_number
    db.scalars.return_value.all.return_value = [active_program]
    get_context = Mock(
        return_value=GeneratorContext(
            user_id=user.id,
            goal="strength",
            experience_level="beginner",
            days_per_week=1,
            available_days=(1,),
            session_duration_minutes=15,
            no_dedicated_leg_day=False,
            arm_specialization=False,
            muscle_priorities={"CHEST": "high", "BACK": "normal"},
            equipment_selection=("BODYWEIGHT",),
            available_equipment=frozenset({"BODYWEIGHT"}),
            sports=(
                SportContext(
                    sport_type="boxing",
                    day_of_week=1,
                    duration_minutes=60,
                    intensity="high",
                ),
            ),
        ),
    )
    monkeypatch.setattr(programs, "build_generator_context", get_context)
    pool = Mock(
        return_value=(
            _candidate(2, "PUSH_UP", "CHEST", "horizontal_push"),
            _candidate(3, "PRONE_PULL", "BACK", "horizontal_pull"),
        ),
    )
    monkeypatch.setattr(builder, "load_exercise_pool", pool)

    app = FastAPI()
    app.include_router(programs.router, prefix="/api/v1")
    app.dependency_overrides[programs.get_current_user] = lambda: user
    app.dependency_overrides[programs.get_db] = lambda: db
    with TestClient(app, raise_server_exceptions=False) as client:
        yield client, db, active_program, get_context, pool


def _candidate(
    id_number: int,
    code: str,
    muscle: str,
    pattern: str,
) -> ExerciseCandidate:
    return ExerciseCandidate(
        id=UUID(int=id_number),
        code=code,
        name=code,
        primary_muscle=muscle,
        secondary_muscles=(),
        movement_pattern=pattern,
        difficulty="beginner",
        is_compound=True,
        min_reps=8,
        max_reps=12,
        rest_seconds=90,
        required_equipment=frozenset({"BODYWEIGHT"}),
    )


def test_duration_fitting_failure_returns_422_and_keeps_active_program(generation):
    client, db, active_program, _, _ = generation

    response = client.post(GENERATE_URL)

    assert db.mock_calls == [call.rollback()]
    assert active_program.status == "active"
    assert response.status_code == 422, response.text
    assert response.json() == {
        "detail": "Unable to fit session 1 within 10 minutes without removing minimum muscle coverage"
    }


def test_missing_eligible_exercises_returns_422_and_keeps_active_program(generation):
    client, db, active_program, _, pool = generation
    pool.return_value = ()

    response = client.post(GENERATE_URL)

    assert db.mock_calls == [call.rollback()]
    assert active_program.status == "active"
    assert response.status_code == 422, response.text
    assert response.json() == {"detail": "No eligible exercises for session 1"}


@pytest.mark.parametrize(
    "error",
    [
        RuntimeError("fixture-only internal diagnostic"),
        OperationalError(None, None, RuntimeError("fixture-only driver diagnostic")),
        VolumeEngineError("fixture-only invalid volume state"),
        SplitEngineError("fixture-only invalid split state"),
        VolumeDistributionError("fixture-only invalid distribution state"),
    ],
    ids=["bug", "database", "volume-invariant", "split-invariant", "distribution-invariant"],
)
def test_internal_failure_remains_500_and_keeps_active_program(generation, error):
    client, db, active_program, _, pool = generation
    pool.side_effect = error

    response = client.post(GENERATE_URL)

    assert response.status_code == 500
    assert response.text == "Internal Server Error"
    assert db.mock_calls == [call.rollback()]
    assert active_program.status == "active"


def test_feasible_duration_still_generates_and_saves_program(generation):
    client, db, active_program, get_context, _ = generation
    get_context.return_value = replace(get_context.return_value, session_duration_minutes=30)

    def assign_id_on_flush():
        added = db.add.call_args.args[0]
        added.id = UUID(int=10 + db.add.call_count)

    def set_created_at_on_refresh(program):
        program.created_at = datetime(2026, 11, 19, tzinfo=timezone.utc)

    db.flush.side_effect = assign_id_on_flush
    db.refresh.side_effect = set_created_at_on_refresh

    response = client.post(GENERATE_URL)

    assert response.status_code == 201, response.text
    payload = response.json()
    assert payload["version_number"] == 2
    assert payload["status"] == "active"
    assert payload["validation_passed"] is True
    assert payload["program_days"] == 1
    assert payload["program_exercises"] == 2
    assert db.add.call_count == 4
    db.commit.assert_called_once_with()
    db.rollback.assert_not_called()
    assert active_program.status == "archived"
