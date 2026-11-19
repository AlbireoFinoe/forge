from collections import Counter
from dataclasses import dataclass, replace
from types import SimpleNamespace
from unittest.mock import Mock
from uuid import UUID

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from pydantic import ValidationError
from sqlalchemy import create_engine, event, select
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.api.v1 import programs, workouts
from app.core.database import Base
from app.generator.builder import build_program_plan
from app.generator.context import GeneratorContext, SportContext
from app.generator.fitter import DurationFitterError
from app.generator.split import MUSCLE_RECOVERY_WEIGHT, PRIORITY_RECOVERY_WEIGHT
from app.generator.validator import validate_program
from app.models import (
    Equipment,
    Exercise,
    ExerciseEquipment,
    Goal,
    MuscleGroup,
    ProgramDay,
    SportActivity,
    TrainingDay,
    TrainingPreference,
    TrainingProgram,
    User,
    UserEquipment,
    UserProfile,
)
from app.schemas.onboarding import TrainingPreferencesUpdate
from app.schemas.program import ProgramDayResponse


MUSCLES = ("CHEST", "BACK", "QUADS", "HAMSTRINGS", "BICEPS", "TRICEPS", "ABS")
GOALS = ("muscle_gain", "strength", "fat_loss", "general_fitness", "hybrid")
EXPERIENCE = ("beginner", "intermediate", "advanced")


@dataclass(frozen=True)
class CatalogEntry:
    muscle: str
    equipment: frozenset[str]
    exercise: SimpleNamespace
    secondary: dict[str, float]


def synthetic_catalog():
    entries = []
    for muscle in MUSCLES:
        for equipment, difficulty, reps, rest in (
            (frozenset({"BODYWEIGHT"}), "beginner", (8, 12), 60),
            (frozenset({"DUMBBELL", "BENCH"}), "intermediate", (6, 10), 90),
        ):
            number = len(entries) + 1
            secondary = {"BICEPS": 0.25} if muscle == "BACK" else {}
            entries.append(
                CatalogEntry(
                    muscle,
                    equipment,
                    SimpleNamespace(
                        id=UUID(int=number),
                        code=f"{muscle}_{number}",
                        name=f"{muscle} fixture {number}",
                        movement_pattern=f"pattern_{number}",
                        difficulty=difficulty,
                        is_compound=muscle in {"CHEST", "BACK", "QUADS", "HAMSTRINGS"},
                        default_min_reps=reps[0],
                        default_max_reps=reps[1],
                        default_rest_seconds=rest,
                    ),
                    secondary,
                )
            )
    return entries


def catalog_session(entries):
    db = Mock(spec=Session)
    db.execute.side_effect = [
        Mock(all=Mock(return_value=rows))
        for rows in (
            [(entry.exercise, entry.muscle) for entry in entries],
            [(entry.exercise.id, code) for entry in entries for code in entry.equipment],
            [
                (entry.exercise.id, muscle, weight)
                for entry in entries
                for muscle, weight in entry.secondary.items()
            ],
        )
    ]
    return db


def generator_context(
    days,
    minutes,
    goal="strength",
    experience="beginner",
    equipment=("FULL_GYM",),
    sports=(),
    *,
    muscles=MUSCLES,
    no_leg_day=False,
):
    priorities = {"CHEST": "high", "TRICEPS": "maintenance"}
    available = {"BODYWEIGHT", "DUMBBELL", "BENCH"} if equipment == ("FULL_GYM",) else {
        "BODYWEIGHT", *equipment
    }
    return GeneratorContext(
        user_id=UUID(int=100),
        goal=goal,
        experience_level=experience,
        days_per_week=len(days),
        available_days=days,
        session_duration_minutes=minutes,
        no_dedicated_leg_day=no_leg_day,
        arm_specialization=True,
        muscle_priorities={muscle: priorities.get(muscle, "normal") for muscle in muscles},
        equipment_selection=equipment,
        available_equipment=frozenset(available),
        sports=sports,
    )


def verify_program(context, catalog, result, validation):
    allocated = Counter()
    exposures = {muscle: set() for muscle in context.muscle_priorities}
    for item in result.distribution_plan.allocations:
        assert item.day_of_week in context.available_days
        assert 1 <= item.target_effective_sets <= 6
        allocated[item.muscle_code] += item.target_effective_sets
        assert item.day_of_week not in exposures[item.muscle_code]
        exposures[item.muscle_code].add(item.day_of_week)
    targets = {
        muscle: item.target_effective_sets
        for muscle, item in result.volume_plan.targets.items()
    }
    assert allocated == targets
    assert all(len(exposures[muscle]) <= target for muscle, target in targets.items())

    split = result.split_plan
    assert [day.day_of_week for day in split.sessions] == sorted(context.available_days)
    assert len({day.key for day in split.sessions}) == context.days_per_week
    expected_recovery = 0.0
    for index, first in enumerate(split.sessions):
        for second in split.sessions[index + 1:]:
            distance = second.day_of_week - first.day_of_week
            proximity = {1: 1.0, 2: 0.25}.get(min(distance, 7 - distance), 0.0)
            for muscle in set(first.focus_muscles).intersection(second.focus_muscles):
                priority = context.muscle_priorities.get(muscle, "normal")
                expected_recovery += (
                    MUSCLE_RECOVERY_WEIGHT[muscle] * PRIORITY_RECOVERY_WEIGHT[priority]
                    * proximity * 4.0
                )
    assert split.total_recovery_conflict_score == round(expected_recovery, 2)

    entries = {entry.exercise.id: entry for entry in catalog}
    actual = dict.fromkeys(targets, 0.0)
    physical_sets = 0
    fitted = result.fitted_program.sessions
    assert [day.day_of_week for day in fitted] == sorted(context.available_days)
    for session in fitted:
        session_actual = dict.fromkeys(targets, 0.0)
        seconds = 480
        count = 0
        for item in session.exercises:
            prescription = item.exercise
            entry = entries[prescription.exercise.id]
            assert entry.equipment <= context.available_equipment
            assert EXPERIENCE.index(entry.exercise.difficulty) <= EXPERIENCE.index(
                context.experience_level
            )
            assert (prescription.min_reps, prescription.max_reps, prescription.rest_seconds) == (
                entry.exercise.default_min_reps,
                entry.exercise.default_max_reps,
                entry.exercise.default_rest_seconds,
            )
            assert 1 <= item.sets <= 10
            count += item.sets
            seconds += 75 + 40 * item.sets + (item.sets - 1) * prescription.rest_seconds
            session_actual[entry.muscle] += item.sets
            for muscle, weight in entry.secondary.items():
                if muscle in session_actual:
                    session_actual[muscle] += item.sets * weight
        assert count == session.physical_sets
        physical_sets += count
        assert session.estimated_duration_minutes == round(seconds / 60)
        assert seconds <= session.available_duration_minutes * 60
        for muscle, target in session.target_effective_sets.items():
            assert session.achieved_effective_sets[muscle] == round(session_actual[muscle], 2)
            assert session.remaining_effective_sets[muscle] == round(
                max(0.0, target - session_actual[muscle]), 2
            )
        for muscle in actual:
            actual[muscle] += session_actual[muscle]

    assert {entry.muscle_code for entry in validation.muscle_volumes} == set(targets)
    for entry in validation.muscle_volumes:
        muscle = entry.muscle_code
        assert entry.target_effective_sets == targets[muscle]
        assert entry.actual_effective_sets == round(actual[muscle], 2)
        assert entry.ratio == round(round(actual[muscle], 2) / targets[muscle], 3)
    assert result.planning_actual_effective_sets == {
        muscle: round(sets, 2) for muscle, sets in actual.items()
    }
    return physical_sets, targets, actual


def run_synthetic_program(context):
    catalog = synthetic_catalog()
    db = catalog_session(catalog)
    result = build_program_plan(db, context)
    validation = validate_program(context, result)
    assert db.execute.call_count == 3
    db.commit.assert_not_called()
    db.flush.assert_not_called()
    physical_sets, targets, actual = verify_program(context, catalog, result, validation)
    return result, validation, physical_sets, targets, actual


@pytest.mark.parametrize("goal", GOALS)
@pytest.mark.parametrize("experience", EXPERIENCE)
def test_goal_experience_matrix(goal, experience):
    context = generator_context((1, 3, 5, 7), 75, goal, experience)
    _, validation, _, _, _ = run_synthetic_program(context)
    assert validation.is_valid, validation.issues


def test_duration_failure_with_high_intensity_sport():
    context = generator_context(
        (1,), 15, equipment=("BODYWEIGHT",),
        sports=(SportContext("boxing", 1, 60, "high"),),
        muscles=("CHEST", "BACK"),
    )
    with pytest.raises(DurationFitterError, match="session 1 within 10 minutes"):
        build_program_plan(catalog_session(synthetic_catalog()), context)


def schedule_profiles():
    return {
        "1d-15m": generator_context((1,), 15, muscles=("CHEST", "BACK")),
        "2d-45m": generator_context((1, 7), 45, "fat_loss", equipment=("DUMBBELL",)),
        "3d-75m": generator_context((1, 3, 7), 75, "muscle_gain", "intermediate"),
        "4d-90m": generator_context((1, 2, 4, 7), 90, "general_fitness", no_leg_day=True),
        "5d-90m": generator_context(
            (1, 2, 3, 5, 7), 90, "hybrid", "intermediate",
            sports=(SportContext("running", 7, 45, "moderate"),),
        ),
        "6d-120m": generator_context(
            (1, 2, 3, 4, 5, 7), 120, "strength", "advanced", equipment=("BODYWEIGHT",),
            sports=(SportContext("cycling", 6, 30, "low"),),
        ),
        "7d-240m": generator_context(tuple(range(1, 8)), 240, "hybrid", "advanced"),
        "7d-15m": generator_context(tuple(range(1, 8)), 15, "strength", "advanced"),
    }


@pytest.mark.parametrize("profile", tuple(schedule_profiles()))
def test_schedule_matrix(profile):
    context = schedule_profiles()[profile]
    if profile == "7d-15m":
        with pytest.raises(DurationFitterError, match="within 15 minutes"):
            run_synthetic_program(context)
        return

    result, validation, physical, targets, actual = run_synthetic_program(context)
    errors = {issue.code for issue in validation.issues if issue.severity == "error"}
    if profile == "2d-45m":
        assert not validation.is_valid
        assert errors == {"WEEKLY_VOLUME_TOO_HIGH"}
    else:
        assert validation.is_valid, validation.issues
    if profile == "1d-15m":
        assert physical == 2
        assert targets == actual == {"CHEST": 1, "BACK": 1}
        assert result.fitted_program.sessions[0].estimated_duration_minutes == 12
    if profile == "5d-90m":
        assert result.fitted_program.sessions[-1].available_duration_minutes == 76


@pytest.mark.parametrize(
    ("estimate", "expected_error"),
    [(0, "SESSION_DURATION_INVALID"), (16, "SESSION_DURATION_EXCEEDED"), (15, None)],
)
def test_validator_requires_positive_estimate_within_effective_budget(estimate, expected_error):
    context = generator_context((1,), 15, muscles=("CHEST", "BACK"))
    result, _, _, _, _ = run_synthetic_program(context)
    original, = result.fitted_program.sessions
    session = replace(original, estimated_duration_minutes=estimate)
    fitted = replace(result.fitted_program, sessions=(session,))

    report = validate_program(context, replace(result, fitted_program=fitted))

    errors = {issue.code for issue in report.issues if issue.severity == "error"}
    assert errors == ({expected_error} if expected_error else set())
    assert report.is_valid == (expected_error is None)


def test_response_duration_is_positive_but_nominal_input_still_has_fifteen_minute_minimum():
    day = {
        "id": UUID(int=1),
        "day_of_week": 1,
        "day_order": 1,
        "name": "Full Body",
        "exercises": [],
    }
    assert ProgramDayResponse(**day, estimated_duration_minutes=12).estimated_duration_minutes == 12
    with pytest.raises(ValidationError, match="estimated_duration_minutes"):
        ProgramDayResponse(**day, estimated_duration_minutes=0)
    with pytest.raises(ValidationError, match="session_duration_minutes"):
        TrainingPreferencesUpdate(days_per_week=1, available_days=[1], session_duration_minutes=14)


@pytest.fixture
def local_sqlite():
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    try:
        yield engine
    finally:
        engine.dispose()


@pytest.mark.parametrize(
    ("nominal_minutes", "rest_seconds", "estimate", "sets"),
    [(30, 60, 12, 1), (90, 30, 14, 2), (90, 60, 15, 2)],
)
def test_program_http_round_trip_into_workout_lifecycle(
    local_sqlite, nominal_minutes, rest_seconds, estimate, sets
):
    catalog = [
        entry for entry in synthetic_catalog()
        if entry.muscle in {"CHEST", "BACK"} and entry.equipment == {"BODYWEIGHT"}
    ]
    with Session(local_sqlite) as db:
        user = User(email="validation@example.test", password_hash="fixture")
        bodyweight = Equipment(code="BODYWEIGHT", name="Bodyweight")
        muscles = {
            entry.muscle: MuscleGroup(code=entry.muscle, name=entry.muscle, region="upper")
            for entry in catalog
        }
        db.add_all([user, bodyweight, *muscles.values()])
        db.flush()
        user_id = user.id
        db.add_all(
            [
                UserProfile(user_id=user_id, experience_level="beginner"),
                Goal(user_id=user_id, primary_goal="strength"),
                TrainingPreference(
                    user_id=user_id, days_per_week=1, session_duration_minutes=nominal_minutes
                ),
                TrainingDay(user_id=user_id, day_of_week=1),
                UserEquipment(user_id=user_id, equipment_id=bodyweight.id),
                SportActivity(
                    user_id=user_id, sport_type="boxing", day_of_week=1,
                    duration_minutes=60, intensity="high",
                ),
            ]
        )
        for entry in catalog:
            values = {**vars(entry.exercise), "default_rest_seconds": rest_seconds}
            db.add(Exercise(primary_muscle_id=muscles[entry.muscle].id, **values))
            db.add(ExerciseEquipment(exercise_id=entry.exercise.id, equipment_id=bodyweight.id))
        db.commit()

    def isolated_db():
        with Session(local_sqlite) as db:
            yield db

    app = FastAPI()
    app.include_router(programs.router, prefix="/api/v1")
    app.include_router(workouts.router, prefix="/api/v1")
    app.dependency_overrides[programs.get_db] = isolated_db
    app.dependency_overrides[programs.get_current_user] = lambda: SimpleNamespace(
        id=user_id, training_setup_revision=1
    )

    with TestClient(app, raise_server_exceptions=False) as client:
        generated = client.post("/api/v1/programs/generate")
        assert generated.status_code == 201, generated.text
        current = client.get("/api/v1/programs/current")
        assert current.status_code == 200
        detail = current.json()
        assert detail["id"] == generated.json()["id"]
        assert len(detail["days"]) == generated.json()["program_days"] == 1
        day = detail["days"][0]
        assert day["estimated_duration_minutes"] == estimate
        assert len(day["exercises"]) == generated.json()["program_exercises"] == 2
        assert {
            (row["exercise_code"], row["sets"], row["min_reps"], row["max_reps"], row["rest_seconds"])
            for row in day["exercises"]
        } == {(entry.exercise.code, sets, 8, 12, rest_seconds) for entry in catalog}

        with Session(local_sqlite) as db:
            preference = db.scalar(select(TrainingPreference))
            preference.session_duration_minutes = 15
            db.commit()

        rejected = client.post("/api/v1/programs/generate")
        assert rejected.status_code == 422
        assert "within 10 minutes" in rejected.json()["detail"]
        assert client.get("/api/v1/programs/current").json() == detail
        with Session(local_sqlite) as db:
            assert [(row.version_number, row.status) for row in db.scalars(select(TrainingProgram))] == [
                (1, "active")
            ]

        with Session(local_sqlite) as db:
            preference = db.scalar(select(TrainingPreference))
            preference.session_duration_minutes = nominal_minutes
            db.commit()

        archived_statuses = []

        def fail_program_day_insert(_mapper, connection, day):
            archived_statuses.append(
                connection.scalar(
                    select(TrainingProgram.status).where(TrainingProgram.version_number == 1)
                )
            )
            day.estimated_duration_minutes = 0

        event.listen(ProgramDay, "before_insert", fail_program_day_insert)
        try:
            storage_failure = client.post("/api/v1/programs/generate")
        finally:
            event.remove(ProgramDay, "before_insert", fail_program_day_insert)

        assert archived_statuses == ["archived"]
        assert storage_failure.status_code == 500
        assert storage_failure.text == "Internal Server Error"
        assert client.get("/api/v1/programs/current").json() == detail
        with Session(local_sqlite) as db:
            assert [(row.version_number, row.status) for row in db.scalars(select(TrainingProgram))] == [
                (1, "active")
            ]

        started = client.post("/api/v1/workouts/start", json={"program_day_id": day["id"]})
        assert started.status_code == 201, started.text
        workout = started.json()
        assert workout["training_program_id"] == detail["id"]
        assert len(workout["exercises"]) == len(day["exercises"])
        for planned, logged in zip(day["exercises"], workout["exercises"], strict=True):
            assert logged["program_exercise_id"] == planned["id"]
            assert logged["exercise_id"] == planned["exercise_id"]
            assert logged["target_sets"] == len(logged["sets"]) == planned["sets"]
            assert logged["target_min_reps"] == planned["min_reps"]
            assert logged["target_max_reps"] == planned["max_reps"]
            assert logged["target_rest_seconds"] == planned["rest_seconds"]
            for workout_set in logged["sets"]:
                response = client.patch(
                    f"/api/v1/workouts/sets/{workout_set['id']}",
                    json={"actual_reps": 10, "rpe": 8},
                )
                assert response.status_code == 200 and response.json()["is_completed"], response.text

        finish_url = f"/api/v1/workouts/{workout['id']}/finish"
        finished = client.post(finish_url)
        assert finished.status_code == 200, finished.text
        assert finished.json()["status"] == "completed"
        assert client.post(finish_url).json() == finished.json()
