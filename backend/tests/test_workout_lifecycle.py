import importlib.util
import os
import threading
import time
import traceback
import uuid
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine, func, select, text
from sqlalchemy.engine import make_url
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import sessionmaker

from app.api.v1 import workouts as workouts_api
from app.api.v1.workouts import (
    finish_workout_endpoint,
    log_workout_set_endpoint,
    skip_workout_exercise_endpoint,
    start_workout_endpoint,
)
from app.core.database import Base
from app.models import Exercise, MuscleGroup, ProgramDay, ProgramExercise
from app.models import TrainingProgram, User, WorkoutExercise
from app.models import WorkoutSession, WorkoutSet
from app.models.workout_session import ACTIVE_WORKOUT_UNIQUE_INDEX
from app.schemas.workout import (
    WorkoutSetLogRequest,
    WorkoutStartRequest,
)
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
    sets=2,
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
            sets=sets,
            min_reps=8,
            max_reps=12,
            rest_seconds=60,
        )
    )
    db.commit()
    return user, program_day


def _create_started_postgres_workout(
    session_factory,
    *,
    sets=2,
):
    with session_factory() as db:
        user, program_day = _create_program(
            db,
            email=f"{uuid.uuid4().hex}@example.test",
            sets=sets,
        )
        workout = start_workout(
            db,
            user,
            program_day.id,
        )
        exercise = db.scalar(
            select(WorkoutExercise).where(
                WorkoutExercise.workout_session_id
                == workout.id
            )
        )
        set_ids = db.scalars(
            select(WorkoutSet.id)
            .where(
                WorkoutSet.workout_exercise_id
                == exercise.id
            )
            .order_by(WorkoutSet.set_number)
        ).all()
        return user.id, workout.id, exercise.id, set_ids


def _make_postgres_workout_finish_eligible(
    session_factory,
    user_id,
    workout_id,
    *,
    skip_exercises=False,
):
    with session_factory() as db:
        user = db.get(User, user_id)
        exercises = db.scalars(
            select(WorkoutExercise)
            .where(
                WorkoutExercise.workout_session_id
                == workout_id
            )
            .order_by(WorkoutExercise.exercise_order)
        ).all()

        for exercise in exercises:
            if skip_exercises:
                workout_service.skip_workout_exercise(
                    db,
                    user,
                    exercise.id,
                )
                continue

            sets = db.scalars(
                select(WorkoutSet)
                .where(
                    WorkoutSet.workout_exercise_id
                    == exercise.id
                )
                .order_by(WorkoutSet.set_number)
            ).all()
            for workout_set in sets:
                log_workout_set(
                    db,
                    user,
                    workout_set.id,
                    actual_reps=8,
                )


def _run_postgres_requests_concurrently(
    session_factory,
    user_id,
    operations,
):
    backend_pids = []

    def run(operation):
        with session_factory() as db:
            user = db.get(User, user_id)
            backend_pids.append(
                db.scalar(text("SELECT pg_backend_pid()"))
            )
            try:
                result = operation(db, user)
            except HTTPException as exc:
                return ("http", exc.status_code)
            return ("ok", result)

    with ThreadPoolExecutor(
        max_workers=len(operations)
    ) as executor:
        outcomes = list(
            executor.map(run, operations)
        )

    assert len(backend_pids) == len(operations)
    assert len(set(backend_pids)) == len(operations)
    return outcomes


def _wait_until_postgres_backend_is_blocked(
    engine,
    *,
    blocked_pid,
    blocker_pid,
    blocked_future,
    timeout=5,
):
    deadline = time.monotonic() + timeout
    last_observation = None
    with engine.connect() as connection:
        while time.monotonic() < deadline:
            result = connection.execute(
                text(
                    """
                    SELECT
                        state,
                        wait_event_type,
                        wait_event,
                        pg_blocking_pids(pid) AS blocking_pids
                    FROM pg_stat_activity
                    WHERE pid = :blocked_pid
                    """
                ),
                {"blocked_pid": blocked_pid},
            ).mappings().one_or_none()
            last_observation = (
                dict(result) if result is not None else None
            )
            blockers = (
                last_observation["blocking_pids"]
                if last_observation is not None
                else []
            )
            if blocker_pid in blockers:
                return True, last_observation
            if blocked_future.done():
                return False, last_observation
            threading.Event().wait(0.01)
    return False, last_observation


def _wait_for_worker_signal(event, future, description, timeout=15):
    deadline = time.monotonic() + timeout
    while not event.is_set():
        if future.done():
            try:
                result = future.result()
            except BaseException as exc:
                raise RuntimeError(
                    f"{description}; worker failed before signaling: "
                    f"{exc!r}"
                ) from exc
            raise RuntimeError(
                f"{description}; worker completed without signaling "
                f"(result={result!r})."
            )

        remaining = deadline - time.monotonic()
        if remaining <= 0:
            return False
        event.wait(min(remaining, 0.05))
    return True


def _run_postgres_pair_with_verified_contention(
    engine,
    session_factory,
    user_id,
    *,
    first_operation,
    second_operation,
    first_lock_acquired,
    second_lock_attempting,
    release_first,
):
    backend_pids = {}

    def run(role, operation):
        with session_factory() as db:
            backend_pids[role] = db.scalar(
                text("SELECT pg_backend_pid()")
            )
            user = db.get(User, user_id)
            try:
                result = operation(db, user)
            except HTTPException as exc:
                return ("http", exc.status_code)
            return ("ok", result)

    executor = ThreadPoolExecutor(max_workers=2)
    first_future = None
    second_future = None
    phase_error = None
    lock_diagnostics = None
    try:
        first_future = executor.submit(
            run,
            "first",
            first_operation,
        )
        if not _wait_for_worker_signal(
            first_lock_acquired,
            first_future,
            "First request did not return from its lock lookup",
        ):
            raise TimeoutError(
                "First request did not return from its lock lookup."
            )

        second_future = executor.submit(
            run,
            "second",
            second_operation,
        )
        if not _wait_for_worker_signal(
            second_lock_attempting,
            second_future,
            "Second request did not reach its lock lookup",
        ):
            raise TimeoutError(
                "Second request did not reach its lock lookup."
            )

        if backend_pids["first"] == backend_pids["second"]:
            raise AssertionError(
                "Both requests used the same PostgreSQL backend PID "
                f"{backend_pids['first']}."
            )

        lock_was_observed, lock_diagnostics = (
            _wait_until_postgres_backend_is_blocked(
                engine,
                blocked_pid=backend_pids["second"],
                blocker_pid=backend_pids["first"],
                blocked_future=second_future,
            )
        )
        second_finished_before_release = second_future.done()
    except BaseException as exc:
        phase_error = exc
    finally:
        release_first.set()
        executor.shutdown(wait=True)

    worker_outcomes = {}
    worker_errors = {}
    for role, future in (
        ("first", first_future),
        ("second", second_future),
    ):
        if future is None:
            continue
        try:
            worker_outcomes[role] = future.result()
        except BaseException as exc:
            worker_errors[role] = "".join(
                traceback.format_exception(
                    type(exc),
                    exc,
                    exc.__traceback__,
                )
            )

    if phase_error is not None or worker_errors:
        diagnostics = [
            f"Coordination failure: {phase_error!r}"
            if phase_error is not None
            else None,
            (
                "Lock observer snapshot: "
                f"{lock_diagnostics!r}"
            ),
            f"Completed worker outcomes: {worker_outcomes!r}",
            *(
                f"{role} worker exception:\n{details}"
                for role, details in worker_errors.items()
            ),
        ]
        raise AssertionError(
            "\n".join(
                detail
                for detail in diagnostics
                if detail is not None
            )
        ) from phase_error

    assert set(backend_pids) == {"first", "second"}
    assert len(set(backend_pids.values())) == 2
    return (
        [
            worker_outcomes["first"],
            worker_outcomes["second"],
        ],
        lock_was_observed,
        second_finished_before_release,
        lock_diagnostics,
    )


def _run_postgres_pair_observing_finish(
    engine,
    session_factory,
    user_id,
    *,
    first_operation,
    finish_operation,
    first_ready,
    release_first,
):
    backend_pids = {}
    finish_started = threading.Event()

    def run(role, operation):
        with session_factory() as db:
            backend_pids[role] = db.scalar(
                text("SELECT pg_backend_pid()")
            )
            user = db.get(User, user_id)
            if role == "finish":
                finish_started.set()
            try:
                result = operation(db, user)
            except HTTPException as exc:
                return ("http", exc.status_code)
            return ("ok", result)

    executor = ThreadPoolExecutor(max_workers=2)
    first_future = None
    finish_future = None
    phase_error = None
    lock_diagnostics = None
    lock_was_observed = False
    finish_completed_before_release = False
    try:
        first_future = executor.submit(
            run,
            "first",
            first_operation,
        )
        if not _wait_for_worker_signal(
            first_ready,
            first_future,
            "First request did not reach its coordinated pause",
        ):
            raise TimeoutError(
                "First request did not reach its coordinated pause."
            )

        finish_future = executor.submit(
            run,
            "finish",
            finish_operation,
        )
        if not _wait_for_worker_signal(
            finish_started,
            finish_future,
            "Finish request did not start",
        ):
            raise TimeoutError("Finish request did not start.")

        first_pid = backend_pids["first"]
        finish_pid = backend_pids["finish"]
        if first_pid == finish_pid:
            raise AssertionError(
                "Both requests used the same PostgreSQL backend PID "
                f"{first_pid}."
            )

        lock_was_observed, lock_diagnostics = (
            _wait_until_postgres_backend_is_blocked(
                engine,
                blocked_pid=finish_pid,
                blocker_pid=first_pid,
                blocked_future=finish_future,
                timeout=5,
            )
        )
        finish_completed_before_release = finish_future.done()
        if (
            not lock_was_observed
            and not finish_completed_before_release
        ):
            raise TimeoutError(
                "Finish neither completed nor showed lock contention "
                f"before timeout; observer={lock_diagnostics!r}"
            )
    except BaseException as exc:
        phase_error = exc
    finally:
        release_first.set()
        executor.shutdown(wait=True)

    outcomes = {}
    worker_errors = {}
    for role, future in (
        ("first", first_future),
        ("finish", finish_future),
    ):
        if future is None:
            continue
        try:
            outcomes[role] = future.result()
        except BaseException as exc:
            worker_errors[role] = "".join(
                traceback.format_exception(
                    type(exc),
                    exc,
                    exc.__traceback__,
                )
            )

    if phase_error is not None or worker_errors:
        details = [
            f"Coordination failure: {phase_error!r}"
            if phase_error is not None
            else None,
            f"Lock observer snapshot: {lock_diagnostics!r}",
            f"Completed worker outcomes: {outcomes!r}",
            *(
                f"{role} worker exception:\n{error}"
                for role, error in worker_errors.items()
            ),
        ]
        raise AssertionError(
            "\n".join(item for item in details if item is not None)
        ) from phase_error

    assert set(backend_pids) == {"first", "finish"}
    assert len(set(backend_pids.values())) == 2
    return (
        outcomes["first"],
        outcomes["finish"],
        lock_was_observed,
        finish_completed_before_release,
        lock_diagnostics,
    )


def _get_workout_exercise_for_user_without_lock(
    db,
    user,
    workout_exercise_id,
):
    return db.execute(
        select(
            WorkoutExercise,
            WorkoutSession,
        )
        .join(
            WorkoutSession,
            WorkoutExercise.workout_session_id
            == WorkoutSession.id,
        )
        .where(
            WorkoutExercise.id
            == workout_exercise_id,
            WorkoutSession.user_id
            == user.id,
        )
    ).one_or_none()


def _get_workout_set_for_user_without_lock(
    db,
    user,
    workout_set_id,
):
    return db.execute(
        select(
            WorkoutSet,
            WorkoutExercise,
            WorkoutSession,
        )
        .join(
            WorkoutExercise,
            WorkoutSet.workout_exercise_id
            == WorkoutExercise.id,
        )
        .join(
            WorkoutSession,
            WorkoutExercise.workout_session_id
            == WorkoutSession.id,
        )
        .where(
            WorkoutSet.id == workout_set_id,
            WorkoutSession.user_id == user.id,
        )
    ).one_or_none()


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


def test_retry_finish_after_success_returns_completed_workout_without_changing_timestamp(
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
    workout_service.skip_workout_exercise(
        db_session,
        user,
        exercise.id,
    )

    first_response = finish_workout_endpoint(
        workout.id,
        current_user=user,
        db=db_session,
    )
    retry_response = finish_workout_endpoint(
        workout.id,
        current_user=user,
        db=db_session,
    )

    assert first_response.status == "completed"
    assert retry_response.status == "completed"
    assert retry_response.completed_at == first_response.completed_at
    persisted_workout = db_session.get(
        WorkoutSession,
        workout.id,
    )
    assert persisted_workout.status == "completed"
    assert (
        persisted_workout.completed_at
        == first_response.completed_at
    )


def test_finish_retry_after_lost_response_is_idempotent(
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
    workout_service.skip_workout_exercise(
        db_session,
        user,
        exercise.id,
    )

    finish_workout_endpoint(
        workout.id,
        current_user=user,
        db=db_session,
    )
    db_session.expire_all()
    committed = db_session.get(
        WorkoutSession,
        workout.id,
    )
    original_completed_at = committed.completed_at

    retry_response = finish_workout_endpoint(
        workout.id,
        current_user=user,
        db=db_session,
    )

    assert retry_response.status == "completed"
    assert retry_response.completed_at == original_completed_at
    persisted = db_session.get(WorkoutSession, workout.id)
    assert persisted.status == "completed"
    assert persisted.completed_at == original_completed_at


def test_finish_rejects_pending_exercises_without_completing_session(
    db_session,
):
    user, program_day = _create_program(db_session)
    workout = start_workout(
        db_session,
        user,
        program_day.id,
    )

    with pytest.raises(HTTPException) as finish_error:
        finish_workout_endpoint(
            workout.id,
            current_user=user,
            db=db_session,
        )

    assert finish_error.value.status_code == 409
    db_session.expire_all()
    persisted = db_session.get(
        WorkoutSession,
        workout.id,
    )
    assert persisted.status == "in_progress"
    assert persisted.completed_at is None


def test_finish_enforces_ownership_and_rejects_cancelled_sessions(
    db_session,
):
    owner, owner_day = _create_program(
        db_session,
        email="finish-owner@example.test",
    )
    other_user, other_day = _create_program(
        db_session,
        email="finish-other@example.test",
    )
    cancelled_user, cancelled_day = _create_program(
        db_session,
        email="finish-cancelled@example.test",
    )

    completed_foreign = start_workout(
        db_session,
        other_user,
        other_day.id,
    )
    completed_exercise = db_session.scalar(
        select(WorkoutExercise).where(
            WorkoutExercise.workout_session_id
            == completed_foreign.id
        )
    )
    workout_service.skip_workout_exercise(
        db_session,
        other_user,
        completed_exercise.id,
    )
    finish_workout_endpoint(
        completed_foreign.id,
        current_user=other_user,
        db=db_session,
    )

    active_foreign = start_workout(
        db_session,
        other_user,
        other_day.id,
    )
    cancelled = start_workout(
        db_session,
        cancelled_user,
        cancelled_day.id,
    )
    cancelled.status = "cancelled"
    db_session.commit()

    for foreign_workout in (
        completed_foreign,
        active_foreign,
    ):
        with pytest.raises(HTTPException) as ownership_error:
            finish_workout_endpoint(
                foreign_workout.id,
                current_user=owner,
                db=db_session,
            )
        assert ownership_error.value.status_code == 404

    with pytest.raises(HTTPException) as cancelled_error:
        finish_workout_endpoint(
            cancelled.id,
            current_user=cancelled_user,
            db=db_session,
        )

    assert cancelled_error.value.status_code == 422
    db_session.expire_all()
    persisted_cancelled = db_session.get(
        WorkoutSession,
        cancelled.id,
    )
    assert persisted_cancelled.status == "cancelled"
    assert persisted_cancelled.completed_at is None

    assert db_session.get(
        WorkoutSession,
        active_foreign.id,
    ).status == "in_progress"


def test_concurrent_finish_requests_are_idempotent(
    isolated_postgres_engine,
    monkeypatch,
):
    session_factory = sessionmaker(
        bind=isolated_postgres_engine
    )
    user_id, workout_id, exercise_id, _ = (
        _create_started_postgres_workout(
            session_factory,
            sets=1,
        )
    )
    _make_postgres_workout_finish_eligible(
        session_factory,
        user_id,
        workout_id,
        skip_exercises=True,
    )
    with session_factory() as db:
        assert db.get(
            WorkoutSession,
            workout_id,
        ).status == "in_progress"
        assert db.get(
            WorkoutExercise,
            exercise_id,
        ).status == "skipped"

    start_barrier = threading.Barrier(2)
    original_finish = workout_service.finish_workout

    def synchronized_finish(db, user, workout_session_id):
        start_barrier.wait(timeout=15)
        return original_finish(
            db,
            user,
            workout_session_id,
        )

    class SteppedClock:
        _counter = 0
        _lock = threading.Lock()

        @classmethod
        def now(cls, tz=None):
            with cls._lock:
                tick = cls._counter
                cls._counter += 1
            return datetime(
                2030,
                1,
                1,
                tzinfo=timezone.utc,
            ) + timedelta(seconds=tick)

    monkeypatch.setattr(
        workouts_api,
        "finish_workout",
        synchronized_finish,
    )
    monkeypatch.setattr(
        workout_service,
        "datetime",
        SteppedClock,
    )

    def finish_operation(db, user):
        return finish_workout_endpoint(
            workout_id,
            current_user=user,
            db=db,
        )

    outcomes = _run_postgres_requests_concurrently(
        session_factory,
        user_id,
        [finish_operation, finish_operation],
    )

    assert [outcome[0] for outcome in outcomes] == ["ok", "ok"]
    responses = [outcome[1] for outcome in outcomes]
    assert all(response.status == "completed" for response in responses)
    assert responses[0].completed_at == responses[1].completed_at

    with session_factory() as db:
        persisted = db.get(WorkoutSession, workout_id)
        assert persisted.status == "completed"
        assert persisted.completed_at == responses[0].completed_at
        assert db.scalar(
            select(func.count())
            .select_from(WorkoutSession)
            .where(WorkoutSession.user_id == user_id)
        ) == 1


def test_finish_and_log_set_obey_a_serial_order(
    isolated_postgres_engine,
    monkeypatch,
):
    session_factory = sessionmaker(
        bind=isolated_postgres_engine
    )
    user_id, workout_id, exercise_id, set_ids = (
        _create_started_postgres_workout(
            session_factory,
            sets=1,
        )
    )
    _make_postgres_workout_finish_eligible(
        session_factory,
        user_id,
        workout_id,
    )
    with session_factory() as db:
        assert db.get(
            WorkoutSession,
            workout_id,
        ).status == "in_progress"
        assert db.get(
            WorkoutExercise,
            exercise_id,
        ).status == "completed"
        assert db.get(
            WorkoutSet,
            set_ids[0],
        ).actual_reps == 8
    first_ready = threading.Event()
    release_first = threading.Event()
    original_get_set = (
        workout_service._get_workout_set_for_user
    )

    def pause_log_after_lookup(db, user, workout_set_id):
        row = original_get_set(
            db,
            user,
            workout_set_id,
        )
        first_ready.set()
        if not release_first.wait(timeout=15):
            raise TimeoutError(
                "Test coordinator did not release Log Set."
            )
        return row

    monkeypatch.setattr(
        workout_service,
        "_get_workout_set_for_user",
        pause_log_after_lookup,
    )

    def log_operation(db, user):
        return log_workout_set_endpoint(
            set_ids[0],
            WorkoutSetLogRequest(actual_reps=12),
            current_user=user,
            db=db,
        )

    def finish_operation(db, user):
        return finish_workout_endpoint(
            workout_id,
            current_user=user,
            db=db,
        )

    (
        log_outcome,
        finish_outcome,
        finish_blocked_by_log,
        finish_completed_before_log_release,
        lock_diagnostics,
    ) = _run_postgres_pair_observing_finish(
        isolated_postgres_engine,
        session_factory,
        user_id,
        first_operation=log_operation,
        finish_operation=finish_operation,
        first_ready=first_ready,
        release_first=release_first,
    )

    assert finish_blocked_by_log or finish_completed_before_log_release, (
        "Finish neither blocked behind Log Set nor completed first; "
        f"observer={lock_diagnostics!r}"
    )
    assert finish_outcome[0] == "ok"
    assert finish_outcome[1].status == "completed"

    with session_factory() as db:
        persisted_workout = db.get(
            WorkoutSession,
            workout_id,
        )
        persisted_set = db.get(
            WorkoutSet,
            set_ids[0],
        )
        assert persisted_workout.status == "completed"
        assert persisted_workout.completed_at is not None
        if finish_completed_before_log_release:
            assert log_outcome == ("http", 422)
            assert persisted_set.actual_reps == 8
        else:
            assert finish_blocked_by_log
            assert log_outcome[0] == "ok"
            assert log_outcome[1].actual_reps == 12
            assert persisted_set.actual_reps == 12
        assert db.get(
            WorkoutExercise,
            exercise_id,
        ).status == "completed"


def test_finish_and_skip_exercise_obey_a_serial_order(
    isolated_postgres_engine,
    monkeypatch,
):
    session_factory = sessionmaker(
        bind=isolated_postgres_engine
    )
    user_id, workout_id, exercise_id, _ = (
        _create_started_postgres_workout(
            session_factory,
            sets=1,
        )
    )
    _make_postgres_workout_finish_eligible(
        session_factory,
        user_id,
        workout_id,
        skip_exercises=True,
    )
    with session_factory() as db:
        assert db.get(
            WorkoutSession,
            workout_id,
        ).status == "in_progress"
        assert db.get(
            WorkoutExercise,
            exercise_id,
        ).status == "skipped"
    first_ready = threading.Event()
    release_first = threading.Event()
    original_get_exercise = (
        workout_service._get_workout_exercise_for_user
    )

    def pause_skip_after_lookup(db, user, workout_exercise_id):
        row = original_get_exercise(
            db,
            user,
            workout_exercise_id,
        )
        first_ready.set()
        if not release_first.wait(timeout=15):
            raise TimeoutError(
                "Test coordinator did not release Skip Exercise."
            )
        return row

    monkeypatch.setattr(
        workout_service,
        "_get_workout_exercise_for_user",
        pause_skip_after_lookup,
    )

    def skip_operation(db, user):
        return skip_workout_exercise_endpoint(
            exercise_id,
            current_user=user,
            db=db,
        )

    def finish_operation(db, user):
        return finish_workout_endpoint(
            workout_id,
            current_user=user,
            db=db,
        )

    (
        skip_outcome,
        finish_outcome,
        finish_blocked_by_skip,
        finish_completed_before_skip_release,
        lock_diagnostics,
    ) = _run_postgres_pair_observing_finish(
        isolated_postgres_engine,
        session_factory,
        user_id,
        first_operation=skip_operation,
        finish_operation=finish_operation,
        first_ready=first_ready,
        release_first=release_first,
    )

    assert finish_blocked_by_skip or finish_completed_before_skip_release, (
        "Finish neither blocked behind Skip Exercise nor completed first; "
        f"observer={lock_diagnostics!r}"
    )
    assert finish_outcome[0] == "ok"
    assert finish_outcome[1].status == "completed"

    with session_factory() as db:
        persisted_workout = db.get(
            WorkoutSession,
            workout_id,
        )
        persisted_exercise = db.get(
            WorkoutExercise,
            exercise_id,
        )
        assert persisted_workout.status == "completed"
        assert persisted_workout.completed_at is not None
        assert persisted_exercise.status == "skipped"
        if finish_completed_before_skip_release:
            assert skip_outcome == ("http", 422)
        else:
            assert finish_blocked_by_skip
            assert skip_outcome[0] == "ok"


def test_concurrent_logs_of_last_sets_leave_exercise_completed(
    isolated_postgres_engine,
    monkeypatch,
):
    session_factory = sessionmaker(
        bind=isolated_postgres_engine
    )
    user_id, workout_id, exercise_id, set_ids = (
        _create_started_postgres_workout(
            session_factory,
            sets=2,
        )
    )
    first_lock_acquired = threading.Event()
    second_lock_attempting = threading.Event()
    release_first = threading.Event()
    original_get_set = (
        workout_service._get_workout_set_for_user
    )

    def coordinated_get_set(db, user, workout_set_id):
        if workout_set_id == set_ids[0]:
            row = original_get_set(
                db,
                user,
                workout_set_id,
            )
            first_lock_acquired.set()
            release_first.wait()
            return row
        second_lock_attempting.set()
        return original_get_set(
            db,
            user,
            workout_set_id,
        )

    monkeypatch.setattr(
        workout_service,
        "_get_workout_set_for_user",
        coordinated_get_set,
    )

    def log_set(workout_set_id, reps):
        def operation(db, user):
            return log_workout_set_endpoint(
                workout_set_id,
                WorkoutSetLogRequest(
                    actual_reps=reps
                ),
                current_user=user,
                db=db,
            )

        return operation

    (
        outcomes,
        lock_was_observed,
        second_finished_before_release,
        lock_diagnostics,
    ) = (
        _run_postgres_pair_with_verified_contention(
            isolated_postgres_engine,
            session_factory,
            user_id,
            first_operation=log_set(set_ids[0], 9),
            second_operation=log_set(set_ids[1], 10),
            first_lock_acquired=first_lock_acquired,
            second_lock_attempting=second_lock_attempting,
            release_first=release_first,
        )
    )

    assert lock_was_observed, (
        "Second PostgreSQL backend was not blocked by the first "
        "request's WorkoutSession row lock. "
        f"Observer snapshot: {lock_diagnostics!r}"
    )
    assert not second_finished_before_release

    assert [outcome[0] for outcome in outcomes] == [
        "ok",
        "ok",
    ]
    with session_factory() as db:
        workout = db.get(WorkoutSession, workout_id)
        exercise = db.get(WorkoutExercise, exercise_id)
        sets = db.scalars(
            select(WorkoutSet)
            .where(
                WorkoutSet.workout_exercise_id
                == exercise_id
            )
            .order_by(WorkoutSet.set_number)
        ).all()

        assert workout.status == "in_progress"
        assert exercise.status == "completed"
        assert [workout_set.actual_reps for workout_set in sets] == [
            9,
            10,
        ]
        assert all(workout_set.is_completed for workout_set in sets)


def test_concurrent_log_and_skip_allow_only_one_transition(
    isolated_postgres_engine,
    monkeypatch,
):
    session_factory = sessionmaker(
        bind=isolated_postgres_engine
    )
    user_id, workout_id, exercise_id, set_ids = (
        _create_started_postgres_workout(
            session_factory,
            sets=1,
        )
    )
    first_lock_acquired = threading.Event()
    second_lock_attempting = threading.Event()
    release_first = threading.Event()
    original_get_set = (
        workout_service._get_workout_set_for_user
    )
    original_get_exercise = (
        workout_service._get_workout_exercise_for_user
    )

    def coordinated_get_set(db, user, workout_set_id):
        row = original_get_set(
            db,
            user,
            workout_set_id,
        )
        first_lock_acquired.set()
        release_first.wait()
        return row

    def coordinated_get_exercise(
        db,
        user,
        workout_exercise_id,
    ):
        second_lock_attempting.set()
        return original_get_exercise(
            db,
            user,
            workout_exercise_id,
        )

    monkeypatch.setattr(
        workout_service,
        "_get_workout_set_for_user",
        coordinated_get_set,
    )
    monkeypatch.setattr(
        workout_service,
        "_get_workout_exercise_for_user",
        coordinated_get_exercise,
    )

    def log_operation(db, user):
        return log_workout_set_endpoint(
            set_ids[0],
            WorkoutSetLogRequest(actual_reps=10),
            current_user=user,
            db=db,
        )

    def skip_operation(db, user):
        return skip_workout_exercise_endpoint(
            exercise_id,
            current_user=user,
            db=db,
        )

    (
        outcomes,
        lock_was_observed,
        second_finished_before_release,
        lock_diagnostics,
    ) = (
        _run_postgres_pair_with_verified_contention(
            isolated_postgres_engine,
            session_factory,
            user_id,
            first_operation=log_operation,
            second_operation=skip_operation,
            first_lock_acquired=first_lock_acquired,
            second_lock_attempting=second_lock_attempting,
            release_first=release_first,
        )
    )

    assert lock_was_observed, (
        "Skip request was not blocked by the Log Set request's "
        "WorkoutSession row lock. "
        f"Observer snapshot: {lock_diagnostics!r}"
    )
    assert not second_finished_before_release

    log_outcome, skip_outcome = outcomes
    assert log_outcome[0] == "ok"
    assert skip_outcome == ("http", 422)
    with session_factory() as db:
        workout = db.get(WorkoutSession, workout_id)
        exercise = db.get(WorkoutExercise, exercise_id)
        workout_set = db.get(WorkoutSet, set_ids[0])

        assert workout.status == "in_progress"
        assert exercise.status == "completed"
        assert workout_set.is_completed
        assert workout_set.actual_reps == 10


def test_negative_control_without_lock_reproduces_final_set_race(
    isolated_postgres_engine,
    monkeypatch,
):
    session_factory = sessionmaker(
        bind=isolated_postgres_engine
    )
    user_id, workout_id, exercise_id, set_ids = (
        _create_started_postgres_workout(
            session_factory,
            sets=2,
        )
    )
    incomplete_set_barrier = threading.Barrier(2)

    def synchronize_incomplete_set_count(db, user, workout_set_id):
        original_scalar = db.scalar

        def wait_before_count(statement, *args, **kwargs):
            if "count(workout_sets.id)" in str(statement).lower():
                incomplete_set_barrier.wait(timeout=15)
            return original_scalar(
                statement,
                *args,
                **kwargs,
            )

        db.scalar = wait_before_count
        return log_workout_set(
            db,
            user,
            workout_set_id,
            actual_reps=10,
        )

    monkeypatch.setattr(
        workout_service,
        "_get_workout_set_for_user",
        _get_workout_set_for_user_without_lock,
    )

    outcomes = _run_postgres_requests_concurrently(
        session_factory,
        user_id,
        [
            lambda db, user: synchronize_incomplete_set_count(
                db,
                user,
                set_ids[0],
            ),
            lambda db, user: synchronize_incomplete_set_count(
                db,
                user,
                set_ids[1],
            ),
        ],
    )

    assert [outcome[0] for outcome in outcomes] == ["ok", "ok"]
    with session_factory() as db:
        exercise = db.get(WorkoutExercise, exercise_id)
        sets = db.scalars(
            select(WorkoutSet)
            .where(
                WorkoutSet.workout_exercise_id
                == exercise_id
            )
            .order_by(WorkoutSet.set_number)
        ).all()

        assert [workout_set.actual_reps for workout_set in sets] == [
            10,
            10,
        ]
        assert all(workout_set.is_completed for workout_set in sets)
        assert exercise.status == "pending"
        assert db.get(WorkoutSession, workout_id).status == "in_progress"


def test_negative_control_without_lock_reproduces_log_skip_race(
    isolated_postgres_engine,
    monkeypatch,
):
    session_factory = sessionmaker(
        bind=isolated_postgres_engine
    )
    user_id, workout_id, exercise_id, set_ids = (
        _create_started_postgres_workout(
            session_factory,
            sets=1,
        )
    )
    log_read = threading.Event()
    skip_committed = threading.Event()

    def log_after_unlocked_read(db, user, workout_set_id):
        row = _get_workout_set_for_user_without_lock(
            db,
            user,
            workout_set_id,
        )
        log_read.set()
        if not skip_committed.wait(timeout=15):
            raise TimeoutError(
                "Skip request did not commit during the negative control."
            )
        return row

    monkeypatch.setattr(
        workout_service,
        "_get_workout_set_for_user",
        log_after_unlocked_read,
    )
    monkeypatch.setattr(
        workout_service,
        "_get_workout_exercise_for_user",
        _get_workout_exercise_for_user_without_lock,
    )

    def log_operation(db, user):
        return log_workout_set_endpoint(
            set_ids[0],
            WorkoutSetLogRequest(actual_reps=10),
            current_user=user,
            db=db,
        )

    def skip_operation(db, user):
        if not log_read.wait(timeout=15):
            raise TimeoutError(
                "Log request did not read the exercise."
            )
        result = skip_workout_exercise_endpoint(
            exercise_id,
            current_user=user,
            db=db,
        )
        skip_committed.set()
        return result

    outcomes = _run_postgres_requests_concurrently(
        session_factory,
        user_id,
        [log_operation, skip_operation],
    )

    assert [outcome[0] for outcome in outcomes] == ["ok", "ok"]
    with session_factory() as db:
        workout = db.get(WorkoutSession, workout_id)
        exercise = db.get(WorkoutExercise, exercise_id)
        workout_set = db.get(WorkoutSet, set_ids[0])

        assert workout.status == "in_progress"
        assert exercise.status == "completed"
        assert workout_set.is_completed
        assert workout_set.actual_reps == 10


def test_concurrent_log_and_finish_serialize_on_workout_session(
    isolated_postgres_engine,
    monkeypatch,
):
    session_factory = sessionmaker(
        bind=isolated_postgres_engine
    )
    user_id, workout_id, exercise_id, set_ids = (
        _create_started_postgres_workout(
            session_factory,
            sets=1,
        )
    )
    first_ready = threading.Event()
    release_first = threading.Event()
    original_get_set = (
        workout_service._get_workout_set_for_user
    )

    def synchronized_get_set(db, user, workout_set_id):
        row = original_get_set(db, user, workout_set_id)
        first_ready.set()
        if not release_first.wait(timeout=15):
            raise TimeoutError(
                "Test coordinator did not release Log Set."
            )
        return row

    monkeypatch.setattr(
        workout_service,
        "_get_workout_set_for_user",
        synchronized_get_set,
    )

    def log_operation(db, user):
        return log_workout_set_endpoint(
            set_ids[0],
            WorkoutSetLogRequest(actual_reps=10),
            current_user=user,
            db=db,
        )

    def finish_operation(db, user):
        return finish_workout_endpoint(
            workout_id,
            current_user=user,
            db=db,
        )

    (
        log_outcome,
        finish_outcome,
        finish_blocked_by_log,
        finish_completed_before_log_release,
        lock_diagnostics,
    ) = _run_postgres_pair_observing_finish(
        isolated_postgres_engine,
        session_factory,
        user_id,
        first_operation=log_operation,
        finish_operation=finish_operation,
        first_ready=first_ready,
        release_first=release_first,
    )

    assert finish_blocked_by_log, (
        "Finish did not block on the Log Set request's "
        f"WorkoutSession lock: {lock_diagnostics!r}"
    )
    assert not finish_completed_before_log_release
    assert log_outcome[0] == "ok"
    assert finish_outcome[0] == "ok"
    assert finish_outcome[1].status == "completed"
    with session_factory() as db:
        workout = db.get(WorkoutSession, workout_id)
        exercise = db.get(WorkoutExercise, exercise_id)
        workout_set = db.get(WorkoutSet, set_ids[0])

        assert workout.status == "completed"
        assert workout.completed_at is not None
        assert exercise.status == "completed"
        assert workout_set.is_completed
        assert workout_set.actual_reps == 10


def test_concurrent_skip_and_finish_serialize_on_workout_session(
    isolated_postgres_engine,
    monkeypatch,
):
    session_factory = sessionmaker(
        bind=isolated_postgres_engine
    )
    user_id, workout_id, exercise_id, _ = (
        _create_started_postgres_workout(
            session_factory,
            sets=1,
        )
    )
    first_ready = threading.Event()
    release_first = threading.Event()
    original_get_exercise = (
        workout_service._get_workout_exercise_for_user
    )

    def synchronized_get_exercise(
        db,
        user,
        workout_exercise_id,
    ):
        row = original_get_exercise(
            db,
            user,
            workout_exercise_id,
        )
        first_ready.set()
        if not release_first.wait(timeout=15):
            raise TimeoutError(
                "Test coordinator did not release Skip Exercise."
            )
        return row

    monkeypatch.setattr(
        workout_service,
        "_get_workout_exercise_for_user",
        synchronized_get_exercise,
    )

    def skip_operation(db, user):
        return skip_workout_exercise_endpoint(
            exercise_id,
            current_user=user,
            db=db,
        )

    def finish_operation(db, user):
        return finish_workout_endpoint(
            workout_id,
            current_user=user,
            db=db,
        )

    (
        skip_outcome,
        finish_outcome,
        finish_blocked_by_skip,
        finish_completed_before_skip_release,
        lock_diagnostics,
    ) = _run_postgres_pair_observing_finish(
        isolated_postgres_engine,
        session_factory,
        user_id,
        first_operation=skip_operation,
        finish_operation=finish_operation,
        first_ready=first_ready,
        release_first=release_first,
    )

    assert finish_blocked_by_skip, (
        "Finish did not block on the Skip Exercise request's "
        f"WorkoutSession lock: {lock_diagnostics!r}"
    )
    assert not finish_completed_before_skip_release
    assert skip_outcome[0] == "ok"
    assert finish_outcome[0] == "ok"
    assert finish_outcome[1].status == "completed"
    with session_factory() as db:
        workout = db.get(WorkoutSession, workout_id)
        exercise = db.get(WorkoutExercise, exercise_id)

        assert workout.status == "completed"
        assert workout.completed_at is not None
        assert exercise.status == "skipped"


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
