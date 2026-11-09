import importlib.util
import os
import threading
import uuid
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine, func, select, text
from sqlalchemy.engine import make_url
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import sessionmaker

from app.api.v1 import workouts as workouts_api
from app.api.v1.workouts import start_workout_endpoint
from app.core.database import Base
from app.models import Exercise, MuscleGroup, ProgramDay, ProgramExercise
from app.models import TrainingProgram, User, WorkoutExercise
from app.models import WorkoutSession, WorkoutSet
from app.models.workout_session import ACTIVE_WORKOUT_UNIQUE_INDEX
from app.schemas.workout import WorkoutStartRequest
from app.services import workout_service
from app.services.workout_service import (
    log_workout_set,
    start_workout,
)


_migration_path = (
    Path(__file__).parents[1]
    / "alembic"
    / "versions"
    / "a4f6c91d2e7b_enforce_one_active_workout_per_user.py"
)
_migration_spec = importlib.util.spec_from_file_location(
    "workout_active_index_migration",
    _migration_path,
)
_workout_migration = importlib.util.module_from_spec(
    _migration_spec
)
_migration_spec.loader.exec_module(_workout_migration)


@pytest.fixture
def db_session():
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)
    session_factory = sessionmaker(bind=engine)

    with session_factory() as db:
        yield db

    Base.metadata.drop_all(engine)
    engine.dispose()


@pytest.fixture
def isolated_postgres_engine():
    database_url = os.environ.get(
        "WORKOUT_TEST_DATABASE_URL"
    )
    if not database_url:
        pytest.skip(
            "Set WORKOUT_TEST_DATABASE_URL to an isolated "
            "PostgreSQL database ending in _test."
        )

    parsed_url = make_url(database_url)
    database_name = parsed_url.database or ""
    if (
        parsed_url.get_backend_name() != "postgresql"
        or not database_name.lower().endswith("_test")
    ):
        pytest.fail(
            "WORKOUT_TEST_DATABASE_URL must target a "
            "PostgreSQL database whose name ends in _test."
        )

    admin_engine = create_engine(
        database_url,
        pool_pre_ping=True,
    )
    schema_name = (
        "workout_test_" + uuid.uuid4().hex
    )
    with admin_engine.begin() as connection:
        current_database = connection.scalar(
            text("SELECT current_database()")
        )
        if current_database != database_name:
            pytest.fail(
                "The PostgreSQL test URL resolved to an "
                "unexpected database."
            )
        connection.exec_driver_sql(
            f'CREATE SCHEMA "{schema_name}"'
        )

    engine = create_engine(
        database_url,
        pool_pre_ping=True,
        pool_size=4,
        max_overflow=0,
        connect_args={
            "options": f"-csearch_path={schema_name}"
        },
    )
    try:
        Base.metadata.create_all(engine)
        yield engine
    finally:
        engine.dispose()
        with admin_engine.begin() as connection:
            connection.exec_driver_sql(
                f'DROP SCHEMA "{schema_name}" CASCADE'
            )
        admin_engine.dispose()


def _create_program(
    db,
    *,
    email="workout@example.test",
):
    user = User(
        email=email,
        password_hash="test-hash",
    )
    muscle_group = MuscleGroup(
        code=f"MUSCLE_{uuid.uuid4().hex}",
        name="Test Muscle",
        region="upper",
    )
    db.add_all([user, muscle_group])
    db.flush()

    exercise = Exercise(
        code=f"EXERCISE_{uuid.uuid4().hex}",
        name="Test Exercise",
        primary_muscle_id=muscle_group.id,
        movement_pattern="push",
        is_compound=True,
        default_min_reps=8,
        default_max_reps=12,
        default_rest_seconds=60,
    )
    db.add(exercise)
    db.flush()

    program = TrainingProgram(
        user_id=user.id,
        name="Test Program",
        goal="strength",
        generator_version="test",
        version_number=1,
        status="active",
    )
    db.add(program)
    db.flush()

    program_day = ProgramDay(
        program_id=program.id,
        day_of_week=1,
        day_order=1,
        name="Test Day",
        estimated_duration_minutes=30,
    )
    db.add(program_day)
    db.flush()

    db.add(
        ProgramExercise(
            program_day_id=program_day.id,
            exercise_id=exercise.id,
            exercise_order=1,
            sets=2,
            min_reps=8,
            max_reps=12,
            rest_seconds=60,
        )
    )
    db.commit()
    return user, program_day


def test_start_workout_creates_session_exercise_and_sets(
    db_session,
):
    user, program_day = _create_program(db_session)

    workout = start_workout(
        db_session,
        user,
        program_day.id,
    )

    exercises = db_session.scalars(
        select(WorkoutExercise).where(
            WorkoutExercise.workout_session_id
            == workout.id
        )
    ).all()
    sets = db_session.scalars(
        select(WorkoutSet).where(
            WorkoutSet.workout_exercise_id
            == exercises[0].id
        )
    ).all()

    assert workout.status == "in_progress"
    assert len(exercises) == 1
    assert len(sets) == 2
    assert all(not workout_set.is_completed for workout_set in sets)


def test_start_again_returns_conflict_when_workout_is_active(
    db_session,
):
    user, program_day = _create_program(db_session)
    start_workout(db_session, user, program_day.id)

    with pytest.raises(HTTPException) as exc_info:
        start_workout_endpoint(
            WorkoutStartRequest(
                program_day_id=program_day.id
            ),
            current_user=user,
            db=db_session,
        )

    assert exc_info.value.status_code == 409
    assert db_session.scalar(
        select(func.count()).select_from(WorkoutSession)
    ) == 1


def test_active_workout_index_violation_maps_to_conflict(
    db_session,
    monkeypatch,
):
    user, program_day = _create_program(db_session)

    class PostgresDiagnostic:
        constraint_name = ACTIVE_WORKOUT_UNIQUE_INDEX

    class PostgresError:
        diag = PostgresDiagnostic()

    def raise_active_workout_violation(**kwargs):
        raise IntegrityError(
            "INSERT INTO workout_sessions",
            {},
            PostgresError(),
        )

    monkeypatch.setattr(
        workouts_api,
        "start_workout",
        raise_active_workout_violation,
    )

    with pytest.raises(HTTPException) as exc_info:
        start_workout_endpoint(
            WorkoutStartRequest(
                program_day_id=program_day.id
            ),
            current_user=user,
            db=db_session,
        )

    assert exc_info.value.status_code == 409


def test_unrelated_integrity_error_is_not_mapped_to_conflict(
    db_session,
    monkeypatch,
):
    user, program_day = _create_program(db_session)

    class PostgresDiagnostic:
        constraint_name = "unrelated_constraint"

    class PostgresError:
        diag = PostgresDiagnostic()

    def raise_unrelated_violation(**kwargs):
        raise IntegrityError(
            "INSERT INTO workout_sessions",
            {},
            PostgresError(),
        )

    monkeypatch.setattr(
        workouts_api,
        "start_workout",
        raise_unrelated_violation,
    )

    with pytest.raises(IntegrityError):
        start_workout_endpoint(
            WorkoutStartRequest(
                program_day_id=program_day.id
            ),
            current_user=user,
            db=db_session,
        )


def test_failed_start_rolls_back_session_and_children(
    db_session,
    monkeypatch,
):
    user, program_day = _create_program(db_session)

    def fail_commit():
        raise RuntimeError("Simulated commit failure")

    monkeypatch.setattr(db_session, "commit", fail_commit)

    with pytest.raises(RuntimeError, match="Simulated commit failure"):
        start_workout(db_session, user, program_day.id)

    assert db_session.scalar(
        select(func.count()).select_from(WorkoutSession)
    ) == 0
    assert db_session.scalar(
        select(func.count()).select_from(WorkoutExercise)
    ) == 0
    assert db_session.scalar(
        select(func.count()).select_from(WorkoutSet)
    ) == 0


def test_different_users_can_each_have_an_active_workout(
    db_session,
):
    first_user, first_day = _create_program(db_session)
    second_user, second_day = _create_program(
        db_session,
        email="second-workout@example.test",
    )

    first_workout = start_workout(
        db_session,
        first_user,
        first_day.id,
    )
    second_workout = start_workout(
        db_session,
        second_user,
        second_day.id,
    )

    assert first_workout.id != second_workout.id
    assert db_session.scalar(
        select(func.count())
        .select_from(WorkoutSession)
        .where(WorkoutSession.status == "in_progress")
    ) == 2


def test_logged_sets_remain_after_workout_completion(
    db_session,
):
    user, program_day = _create_program(db_session)
    workout = start_workout(
        db_session,
        user,
        program_day.id,
    )
    exercise = db_session.scalar(
        select(WorkoutExercise).where(
            WorkoutExercise.workout_session_id
            == workout.id
        )
    )
    sets = db_session.scalars(
        select(WorkoutSet)
        .where(
            WorkoutSet.workout_exercise_id
            == exercise.id
        )
        .order_by(WorkoutSet.set_number)
    ).all()

    for workout_set in sets:
        log_workout_set(
            db_session,
            user,
            workout_set.id,
            actual_reps=10,
        )

    completed_workout = workout_service.finish_workout(
        db_session,
        user,
        workout.id,
    )
    persisted_sets = db_session.scalars(
        select(WorkoutSet)
        .where(
            WorkoutSet.workout_exercise_id
            == exercise.id
        )
        .order_by(WorkoutSet.set_number)
    ).all()

    assert completed_workout.status == "completed"
    assert completed_workout.completed_at is not None
    assert len(persisted_sets) == 2
    assert all(workout_set.is_completed for workout_set in persisted_sets)
    assert [workout_set.actual_reps for workout_set in persisted_sets] == [
        10,
        10,
    ]

    next_workout = start_workout(
        db_session,
        user,
        program_day.id,
    )
    assert next_workout.id != completed_workout.id
    assert completed_workout.status == "completed"
    assert next_workout.status == "in_progress"


def test_migration_refuses_existing_duplicate_active_workouts_without_deleting(
    tmp_path,
):
    engine = create_engine(
        f"sqlite+pysqlite:///{tmp_path / 'migration-check.db'}"
    )
    with engine.begin() as connection:
        connection.exec_driver_sql(
            "CREATE TABLE workout_sessions "
            "(user_id TEXT NOT NULL, status TEXT NOT NULL)"
        )
        connection.exec_driver_sql(
            "INSERT INTO workout_sessions (user_id, status) "
            "VALUES ('same-user', 'in_progress'), "
            "('same-user', 'in_progress'), "
            "('other-user', 'completed')"
        )

        with pytest.raises(
            RuntimeError,
            match="Resolve the duplicates manually",
        ):
            _workout_migration._check_for_duplicate_active_workouts(
                connection
            )

        assert connection.scalar(
            text("SELECT COUNT(*) FROM workout_sessions")
        ) == 3

    engine.dispose()


def test_concurrent_starts_use_independent_postgres_connections_and_one_wins(
    isolated_postgres_engine,
    monkeypatch,
):
    session_factory = sessionmaker(
        bind=isolated_postgres_engine
    )
    with session_factory() as db:
        user, program_day = _create_program(db)
        user_id = user.id
        program_day_id = program_day.id

    start_barrier = threading.Barrier(2)
    backend_pids = []
    original_get_in_progress = (
        workout_service.get_in_progress_workout
    )

    def synchronized_active_workout_check(db, user):
        workout = original_get_in_progress(db, user)
        backend_pid = db.scalar(
            text("SELECT pg_backend_pid()")
        )
        backend_pids.append(backend_pid)
        start_barrier.wait(timeout=15)
        return workout

    monkeypatch.setattr(
        workout_service,
        "get_in_progress_workout",
        synchronized_active_workout_check,
    )

    def send_start_request():
        with session_factory() as db:
            user = db.get(User, user_id)
            try:
                workout = start_workout_endpoint(
                    WorkoutStartRequest(
                        program_day_id=program_day_id
                    ),
                    current_user=user,
                    db=db,
                )
            except HTTPException as exc:
                return ("conflict", exc.status_code)
            return ("created", workout.id)

    with ThreadPoolExecutor(max_workers=2) as executor:
        results = list(
            executor.map(
                lambda _: send_start_request(),
                range(2),
            )
        )

    assert len(set(backend_pids)) == 2
    assert sorted(result[0] for result in results) == [
        "conflict",
        "created",
    ]
    assert next(
        result[1]
        for result in results
        if result[0] == "conflict"
    ) == 409

    with session_factory() as db:
        active_workouts = db.scalars(
            select(WorkoutSession).where(
                WorkoutSession.user_id == user_id,
                WorkoutSession.status == "in_progress",
            )
        ).all()
        assert len(active_workouts) == 1
        exercises = db.scalars(
            select(WorkoutExercise).where(
                WorkoutExercise.workout_session_id
                == active_workouts[0].id
            )
        ).all()
        assert len(exercises) == 1
        assert db.scalar(
            select(func.count())
            .select_from(WorkoutSet)
            .where(
                WorkoutSet.workout_exercise_id
                == exercises[0].id
            )
        ) == 2
