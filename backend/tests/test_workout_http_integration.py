import os
import queue
import secrets
import subprocess
import sys
import threading
import time
import uuid
from collections.abc import Iterator
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field
from datetime import datetime
from decimal import Decimal
from pathlib import Path

import httpx
import pytest
from sqlalchemy import create_engine, text
from sqlalchemy.engine import make_url


EXPECTED_DATABASE = "forge_workout_integration_test"
EXPECTED_REVISION = "a4f6c91d2e7b"
OPT_IN_VARIABLE = "FORGE_WORKOUT_HTTP_INTEGRATION"
DATABASE_URL_VARIABLE = "FORGE_WORKOUT_TEST_DATABASE_URL"

BACKEND_DIRECTORY = Path(__file__).parents[1]
PG_TEST_OPTIONS = "-csearch_path=public"
# Restrict child environment to OS/Python process essentials plus our explicit test settings.
CHILD_ENV_ALLOWLIST = frozenset({
    "SYSTEMROOT", "WINDIR", "SYSTEMDRIVE", "PATH", "PATHEXT", "COMSPEC",
    "TEMP", "TMP", "USERPROFILE", "APPDATA", "LOCALAPPDATA", "VIRTUAL_ENV",
    "PYTHONIOENCODING", "PYTHONUTF8", "HOMEDRIVE", "HOMEPATH",
})


def _isolate_libpq_environment(environment) -> None:
    """Discard inherited libpq routing/configuration and pin schema for this process.

    An explicit URL host alone cannot neutralize an inherited PGHOSTADDR.
    The test must be run alone; no application engine may exist when this runs.
    """
    for key in tuple(environment):
        if key.upper().startswith("PG"):
            environment.pop(key, None)
    environment["PGOPTIONS"] = PG_TEST_OPTIONS


def _assert_database_identity(connection) -> None:
    database, schema = connection.execute(
        text("SELECT current_database(), current_schema()")
    ).one()
    revisions = connection.execute(
        text("SELECT version_num FROM public.alembic_version")
    ).scalars().all()
    if (
        database != EXPECTED_DATABASE
        or schema != "public"
        or revisions != [EXPECTED_REVISION]
    ):
        raise RuntimeError("Unexpected integration database, schema, or revision")

_SERVER_BOOTSTRAP = """
import os
import socket

from sqlalchemy import create_engine, text


def verify_connection(connection):
    db, schema = connection.execute(
        text("SELECT current_database(), current_schema()")
    ).one()
    revisions = connection.execute(
        text("SELECT version_num FROM public.alembic_version")
    ).scalars().all()
    if db != "forge_workout_integration_test" or schema != "public":
        raise RuntimeError("Unexpected test database or schema")
    if revisions != ["a4f6c91d2e7b"]:
        raise RuntimeError("Unexpected test migration revision")


try:
    # Pin the actual TCP destination. The child environment also excludes all
    # inherited PG* variables except the explicit, test-owned PGOPTIONS.
    engine = create_engine(
        os.environ["DATABASE_URL"],
        connect_args={
            "hostaddr": "127.0.0.1",
            "options": "-csearch_path=public",
            "connect_timeout": 5,
        },
        hide_parameters=True,
        pool_pre_ping=True,
    )
    try:
        with engine.connect() as connection:
            verify_connection(connection)
    finally:
        engine.dispose()

    # Verify the application's *real* engine, not merely the bootstrap engine.
    from app.core.database import engine as application_engine
    with application_engine.connect() as connection:
        verify_connection(connection)
except Exception:
    raise SystemExit("Integration server database preflight failed") from None

import uvicorn

# The server process itself owns and RETAINS the bound socket. The parent does
# not choose a port or probe until a nonce-authenticated bind notification.
with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
    listener.bind(("127.0.0.1", 0))
    listener.listen(128)
    listener.setblocking(False)
    port = listener.getsockname()[1]
    nonce = os.environ["FORGE_HTTP_HANDSHAKE_NONCE"]
    print(f"FORGE_HTTP_BOUND:{nonce}:{port}", flush=True)
    config = uvicorn.Config(
        "app.main:app",
        host="127.0.0.1",
        port=port,
        log_level="warning",
        workers=1,
    )
    uvicorn.Server(config).run(sockets=[listener])
"""


@dataclass(frozen=True, repr=False)
class IntegrationTarget:
    database_url: str = field(repr=False)
    jwt_secret: str = field(repr=False)


@dataclass(frozen=True, repr=False)
class TestAccount:
    __test__ = False
    email: str
    user_id: uuid.UUID
    access_token: str = field(repr=False)


@dataclass(frozen=True, repr=False)
class WorkoutCase:
    account: TestAccount
    program_day_id: uuid.UUID
    exercise_ids: tuple[uuid.UUID, ...]
    exercise_codes: tuple[str, ...]
    muscle_group_id: uuid.UUID


@pytest.fixture(scope="session")
def integration_target() -> IntegrationTarget:
    opt_in = os.environ.get(OPT_IN_VARIABLE)
    if opt_in is None:
        pytest.skip(
            f"Set {OPT_IN_VARIABLE}=1 to explicitly enable "
            "real-PostgreSQL HTTP integration tests."
        )
    if opt_in != "1":
        pytest.fail(
            f"{OPT_IN_VARIABLE} must be exactly '1'.",
            pytrace=False,
        )

    if "app.core.config" in sys.modules or "app.core.database" in sys.modules:
        pytest.fail(
            "Run this module alone so the application cannot be initialized "
            "from an unverified environment.",
            pytrace=False,
        )

    database_url = os.environ.get(DATABASE_URL_VARIABLE)
    if not database_url:
        pytest.fail(
            f"{DATABASE_URL_VARIABLE} must explicitly name the approved "
            "integration database.",
            pytrace=False,
        )

    try:
        parsed_url = make_url(database_url)
    except Exception:
        pytest.fail(
            f"{DATABASE_URL_VARIABLE} is not a valid SQLAlchemy URL.",
            pytrace=False,
        )

    if (
        parsed_url.drivername != "postgresql+psycopg"
        or parsed_url.host != "127.0.0.1"
        or parsed_url.port != 5432
        or parsed_url.database != EXPECTED_DATABASE
        or parsed_url.username != "forge"
        or bool(parsed_url.query)
    ):
        pytest.fail(
            f"{DATABASE_URL_VARIABLE} must use "
            "postgresql+psycopg://...@127.0.0.1:5432/"
            f"{EXPECTED_DATABASE} with no URL query options.",
            pytrace=False,
        )

    # Must sanitize BEFORE the first PostgreSQL connection, not just before
    # starting the child: PGHOSTADDR can override the URL's numeric host.
    _isolate_libpq_environment(os.environ)
    preflight_engine = create_engine(
        database_url,
        connect_args={
            "hostaddr": "127.0.0.1",
            "options": PG_TEST_OPTIONS,
            "connect_timeout": 5,
        },
        hide_parameters=True,
        pool_pre_ping=True,
    )
    try:
        with preflight_engine.connect() as connection:
            _assert_database_identity(connection)
    except Exception:
        pytest.fail(
            "The approved local database, schema, and Alembic revision "
            "could not be verified; connection details were suppressed.",
            pytrace=False,
        )
    finally:
        preflight_engine.dispose()

    jwt_secret = secrets.token_urlsafe(48)
    os.environ["DATABASE_URL"] = database_url
    os.environ["JWT_SECRET_KEY"] = jwt_secret
    os.environ["JWT_ALGORITHM"] = "HS256"
    os.environ["JWT_ACCESS_TOKEN_EXPIRE_MINUTES"] = "60"
    os.environ["JWT_REFRESH_TOKEN_EXPIRE_DAYS"] = "30"
    # PGOPTIONS deliberately remains pinned for app.core.database's own
    # engine, which does not otherwise specify a PostgreSQL search_path.
    try:
        from app.core.database import engine as application_engine
        with application_engine.connect() as connection:
            _assert_database_identity(connection)
    except Exception:
        pytest.fail(
            "The application's SQLAlchemy engine did not verify the exact "
            "local integration database/schema/revision.",
            pytrace=False,
        )

    return IntegrationTarget(
        database_url=database_url,
        jwt_secret=jwt_secret,
    )


@pytest.fixture(scope="session")
def integration_server(
    integration_target: IntegrationTarget,
) -> Iterator[str]:
    handshake_nonce = secrets.token_hex(24)
    server_environment = {
        name: value for name, value in os.environ.items()
        if name.upper() in CHILD_ENV_ALLOWLIST
    }
    server_environment.update({
        "DATABASE_URL": integration_target.database_url,
        "JWT_SECRET_KEY": integration_target.jwt_secret,
        "JWT_ALGORITHM": "HS256",
        "JWT_ACCESS_TOKEN_EXPIRE_MINUTES": "60",
        "JWT_REFRESH_TOKEN_EXPIRE_DAYS": "30",
        "PGOPTIONS": PG_TEST_OPTIONS,
        "FORGE_HTTP_HANDSHAKE_NONCE": handshake_nonce,
    })

    process = subprocess.Popen(
        [sys.executable, "-c", _SERVER_BOOTSTRAP],
        cwd=BACKEND_DIRECTORY,
        env=server_environment,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        bufsize=1,
    )

    try:
        # Reading a subprocess pipe can block; use a bounded queue wait.
        handshake_lines = queue.Queue(maxsize=1)

        def receive_handshake() -> None:
            try:
                line = process.stdout.readline() if process.stdout else ""
            except OSError:
                line = ""
            handshake_lines.put(line)

        threading.Thread(target=receive_handshake, daemon=True).start()
        try:
            line = handshake_lines.get(timeout=15)
        except queue.Empty:
            pytest.fail(
                "The child server did not acknowledge its loopback port "
                "before the startup deadline.",
                pytrace=False,
            )

        expected_prefix = f"FORGE_HTTP_BOUND:{handshake_nonce}:"
        port_text = (
            line.strip()[len(expected_prefix):]
            if line.startswith(expected_prefix)
            else ""
        )
        if not port_text.isdecimal() or not (1 <= int(port_text) <= 65535):
            pytest.fail(
                "The child server did not prove ownership of a bound "
                "loopback socket.",
                pytrace=False,
            )
        port = int(port_text)
        base_url = f"http://127.0.0.1:{port}"

        ready = False
        deadline = time.monotonic() + 15
        with httpx.Client(timeout=0.5, trust_env=False) as client:
            while time.monotonic() < deadline:
                if process.poll() is not None:
                    break
                try:
                    health = client.get(f"{base_url}/api/v1/health")
                    database_health = client.get(
                        f"{base_url}/api/v1/health/database"
                    )
                    if (
                        health.status_code == 200
                        and health.json()
                        == {"status": "ok", "service": "forge-api"}
                        and database_health.status_code == 200
                        and database_health.json()
                        == {"status": "ok", "database": "connected"}
                    ):
                        ready = True
                        break
                except httpx.RequestError:
                    pass
                time.sleep(0.1)

        if not ready:
            pytest.fail(
                "The isolated loopback FastAPI server did not pass its "
                "network and database readiness checks.",
                pytrace=False,
            )

        yield base_url
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)

        if process.stdout is not None:
            process.stdout.close()

        database_module = sys.modules.get("app.core.database")
        if database_module is not None:
            database_module.engine.dispose()


@pytest.fixture
def api_client(integration_server: str) -> Iterator[httpx.Client]:
    with httpx.Client(
        base_url=integration_server,
        timeout=10,
        trust_env=False,
    ) as client:
        yield client


def _register_and_login(client) -> TestAccount:
    email = f"workout-http-{uuid.uuid4().hex}@example.com"
    password = secrets.token_urlsafe(24)
    authenticated = False
    try:
        registration = client.post(
            "/api/v1/auth/register",
            json={
                "full_name": "Workout HTTP Integration",
                "email": email,
                "password": password,
            },
        )
        assert registration.status_code == 201, (
            "POST /auth/register should create a unique test account."
        )
        registration_body = registration.json()
        assert registration_body["email"] == email
        assert registration_body["is_active"] is True
        user_id = uuid.UUID(registration_body["id"])

        login = client.post(
            "/api/v1/auth/login",
            json={"email": email, "password": password},
        )
        assert login.status_code == 200, "POST /auth/login should succeed."
        login_body = login.json()
        assert login_body["token_type"] == "bearer"
        assert login_body["access_token"]
        assert login_body["refresh_token"]

        account = TestAccount(
            email=email,
            user_id=user_id,
            access_token=login_body["access_token"],
        )
        authenticated = True
        return account
    finally:
        if not authenticated:
            _delete_account_by_email(email)


def _delete_account_by_email(email: str) -> None:
    from sqlalchemy import delete, select

    from app.core.database import SessionLocal
    from app.models.user import User

    with SessionLocal() as db:
        user_id = db.scalar(
            select(User.id).where(User.email == email)
        )
        if user_id is not None:
            db.execute(delete(User).where(User.id == user_id))
            db.commit()


@pytest.fixture
def workout_case(api_client) -> Iterator[WorkoutCase]:
    from sqlalchemy import delete, select

    from app.core.database import SessionLocal
    from app.models.exercise import Exercise
    from app.models.muscle_group import MuscleGroup
    from app.models.program_day import ProgramDay
    from app.models.program_exercise import ProgramExercise
    from app.models.training_program import TrainingProgram
    from app.models.user import User
    from app.models.workout_session import WorkoutSession

    account = _register_and_login(api_client)
    muscle_group_id = uuid.uuid4()
    exercise_ids = (uuid.uuid4(), uuid.uuid4())
    exercise_codes = (
        f"HTTP_TEST_{uuid.uuid4().hex}",
        f"HTTP_TEST_{uuid.uuid4().hex}",
    )

    try:
        with SessionLocal() as db:
            user = db.get(User, account.user_id)
            assert user is not None, (
                "The registered integration user must persist."
            )

            muscle_group = MuscleGroup(
                id=muscle_group_id,
                code=f"HTTP_TEST_{uuid.uuid4().hex}",
                name="HTTP Integration Muscle",
                region="upper",
            )
            db.add(muscle_group)
            db.flush()

            exercises = [
                Exercise(
                    id=exercise_id,
                    code=exercise_code,
                    name=f"HTTP Integration Exercise {index}",
                    primary_muscle_id=muscle_group.id,
                    movement_pattern="push",
                    difficulty="intermediate",
                    is_compound=True,
                    default_min_reps=8,
                    default_max_reps=12,
                    default_rest_seconds=60,
                )
                for index, (exercise_id, exercise_code) in enumerate(
                    zip(exercise_ids, exercise_codes),
                    start=1,
                )
            ]
            db.add_all(exercises)
            db.flush()

            program = TrainingProgram(
                user_id=user.id,
                name="HTTP Integration Program",
                goal="strength",
                generator_version="integration-test",
                version_number=1,
                setup_revision=user.training_setup_revision,
                status="active",
            )
            db.add(program)
            db.flush()

            program_day = ProgramDay(
                program_id=program.id,
                day_of_week=1,
                day_order=1,
                name="HTTP Integration Day",
                estimated_duration_minutes=30,
            )
            db.add(program_day)
            db.flush()

            db.add_all(
                [
                    ProgramExercise(
                        program_day_id=program_day.id,
                        exercise_id=exercise.id,
                        exercise_order=index,
                        sets=1,
                        min_reps=8,
                        max_reps=12,
                        rest_seconds=60,
                    )
                    for index, exercise in enumerate(exercises, start=1)
                ]
            )
            db.commit()
            case = WorkoutCase(
                account=account,
                program_day_id=program_day.id,
                exercise_ids=exercise_ids,
                exercise_codes=exercise_codes,
                muscle_group_id=muscle_group_id,
            )

        yield case
    finally:
        with SessionLocal() as db:
            user_id = db.scalar(
                select(User.id).where(User.email == account.email)
            )
            if user_id is not None:
                program_ids = select(TrainingProgram.id).where(
                    TrainingProgram.user_id == user_id
                )
                program_day_ids = select(ProgramDay.id).where(
                    ProgramDay.program_id.in_(program_ids)
                )
                db.execute(
                    delete(WorkoutSession).where(
                        WorkoutSession.user_id == user_id
                    )
                )
                db.execute(
                    delete(ProgramExercise).where(
                        ProgramExercise.program_day_id.in_(program_day_ids)
                    )
                )
                db.execute(
                    delete(ProgramDay).where(
                        ProgramDay.program_id.in_(program_ids)
                    )
                )
                db.execute(
                    delete(TrainingProgram).where(
                        TrainingProgram.user_id == user_id
                    )
                )
                db.execute(delete(User).where(User.id == user_id))

            db.execute(
                delete(Exercise).where(Exercise.id.in_(exercise_ids))
            )
            db.execute(
                delete(MuscleGroup).where(
                    MuscleGroup.id == muscle_group_id
                )
            )
            db.commit()


def test_workout_http_authentication_and_authorization(
    api_client,
    workout_case: WorkoutCase,
) -> None:
    unauthenticated = api_client.get("/api/v1/workouts/current")
    assert unauthenticated.status_code == 401, (
        "Workout routes must reject requests without a bearer token."
    )

    malformed_token = api_client.get(
        "/api/v1/workouts/current",
        headers={"Authorization": "Bearer not-a-valid-jwt"},
    )
    assert malformed_token.status_code == 401, (
        "Workout routes must reject malformed bearer tokens."
    )

    authenticated = api_client.get(
        "/api/v1/workouts/current",
        headers={
            "Authorization": f"Bearer {workout_case.account.access_token}"
        },
    )
    assert authenticated.status_code == 404, (
        "A valid account without an active workout should receive 404."
    )
    assert authenticated.json()["detail"] == "No workout in progress"


def test_workout_http_lifecycle_persists_and_finishes_idempotently(
    api_client,
    workout_case: WorkoutCase,
) -> None:
    from sqlalchemy import select

    from app.core.database import SessionLocal
    from app.models.workout_exercise import WorkoutExercise
    from app.models.workout_session import WorkoutSession
    from app.models.workout_set import WorkoutSet

    account = workout_case.account
    headers = {"Authorization": f"Bearer {account.access_token}"}

    started = api_client.post(
        "/api/v1/workouts/start",
        headers=headers,
        json={"program_day_id": str(workout_case.program_day_id)},
    )
    assert started.status_code == 201, (
        "POST /workouts/start should create a session."
    )
    start_body = started.json()
    workout_id = uuid.UUID(start_body["id"])
    assert start_body["status"] == "in_progress"
    assert start_body["program_day_id"] == str(workout_case.program_day_id)
    assert start_body["completed_at"] is None
    assert len(start_body["exercises"]) == 2
    assert [exercise["exercise_code"] for exercise in start_body["exercises"]] == (
        list(workout_case.exercise_codes)
    )
    assert all(
        exercise["status"] == "pending"
        and len(exercise["sets"]) == 1
        and exercise["sets"][0]["is_completed"] is False
        for exercise in start_body["exercises"]
    )

    with SessionLocal() as db:
        persisted_workout = db.get(WorkoutSession, workout_id)
        assert persisted_workout is not None, (
            "Starting through HTTP must persist a workout session."
        )
        assert persisted_workout.user_id == account.user_id
        assert persisted_workout.status == "in_progress"
        exercise_rows = db.scalars(
            select(WorkoutExercise)
            .where(WorkoutExercise.workout_session_id == workout_id)
            .order_by(WorkoutExercise.exercise_order)
        ).all()
        assert len(exercise_rows) == 2
        assert all(exercise.status == "pending" for exercise in exercise_rows)
        set_rows = db.scalars(
            select(WorkoutSet).where(
                WorkoutSet.workout_exercise_id.in_(
                    [exercise.id for exercise in exercise_rows]
                )
            )
        ).all()
        assert len(set_rows) == 2

    duplicate_start = api_client.post(
        "/api/v1/workouts/start",
        headers=headers,
        json={"program_day_id": str(workout_case.program_day_id)},
    )
    assert duplicate_start.status_code == 409, (
        "Starting a second workout while one is active must conflict."
    )

    current = api_client.get("/api/v1/workouts/current", headers=headers)
    assert current.status_code == 200
    assert current.json()["id"] == str(workout_id)

    pending_finish = api_client.post(
        f"/api/v1/workouts/{workout_id}/finish",
        headers=headers,
    )
    assert pending_finish.status_code == 409, (
        "A workout with pending exercises must not finish."
    )

    first_exercise, skipped_exercise = start_body["exercises"]
    first_set_id = uuid.UUID(first_exercise["sets"][0]["id"])
    skipped_set_id = uuid.UUID(skipped_exercise["sets"][0]["id"])
    logged_set = api_client.patch(
        f"/api/v1/workouts/sets/{first_set_id}",
        headers=headers,
        json={"actual_reps": 10, "weight_kg": 20.5, "rpe": 8},
    )
    assert logged_set.status_code == 200
    assert logged_set.json()["is_completed"] is True
    assert logged_set.json()["actual_reps"] == 10
    assert Decimal(str(logged_set.json()["weight_kg"])) == Decimal("20.5")
    assert Decimal(str(logged_set.json()["rpe"])) == Decimal("8")
    with SessionLocal() as db:
        persisted_set = db.get(WorkoutSet, first_set_id)
        assert persisted_set is not None
        assert persisted_set.is_completed is True
        assert persisted_set.actual_reps == 10
        assert persisted_set.weight_kg == Decimal("20.50")
        assert persisted_set.rpe == Decimal("8.0")
        completed_exercise = db.get(
            WorkoutExercise,
            uuid.UUID(first_exercise["id"]),
        )
        assert completed_exercise is not None
        assert completed_exercise.status == "completed"

    skipped = api_client.post(
        f"/api/v1/workouts/exercises/{skipped_exercise['id']}/skip",
        headers=headers,
    )
    assert skipped.status_code == 200
    assert skipped.json()["status"] == "skipped"
    with SessionLocal() as db:
        persisted_skipped_exercise = db.get(
            WorkoutExercise,
            uuid.UUID(skipped_exercise["id"]),
        )
        assert persisted_skipped_exercise is not None
        assert persisted_skipped_exercise.status == "skipped"

    skip_completed = api_client.post(
        f"/api/v1/workouts/exercises/{first_exercise['id']}/skip",
        headers=headers,
    )
    assert skip_completed.status_code == 422
    log_skipped = api_client.patch(
        f"/api/v1/workouts/sets/{skipped_set_id}",
        headers=headers,
        json={"actual_reps": 8},
    )
    assert log_skipped.status_code == 422

    # Separate clients and a barrier exercise simultaneous real HTTP requests.
    barrier = threading.Barrier(2)

    def finish_from_network():
        import httpx

        with httpx.Client(
            base_url=str(api_client.base_url),
            timeout=10,
            trust_env=False,
        ) as client:
            barrier.wait(timeout=5)
            return client.post(
                f"/api/v1/workouts/{workout_id}/finish",
                headers=headers,
            )

    with ThreadPoolExecutor(max_workers=2) as executor:
        concurrent_finishes = list(
            executor.map(
                lambda _: finish_from_network(),
                range(2),
            )
        )

    assert [response.status_code for response in concurrent_finishes] == [
        200,
        200,
    ], "Concurrent finish requests should both return the completed session."
    concurrent_bodies = [response.json() for response in concurrent_finishes]
    completed_at = concurrent_bodies[0]["completed_at"]
    assert completed_at
    assert all(body["status"] == "completed" for body in concurrent_bodies)
    assert all(body["completed_at"] == completed_at for body in concurrent_bodies)

    retry = api_client.post(
        f"/api/v1/workouts/{workout_id}/finish",
        headers=headers,
    )
    assert retry.status_code == 200
    retry_body = retry.json()
    assert retry_body["status"] == "completed"
    assert retry_body["completed_at"] == completed_at, (
        "Retrying Finish must preserve the original completion timestamp."
    )
    expected_completed_at = datetime.fromisoformat(
        completed_at.replace("Z", "+00:00")
    )
    with SessionLocal() as db:
        persisted_workout = db.get(WorkoutSession, workout_id)
        assert persisted_workout is not None
        assert persisted_workout.status == "completed"
        assert persisted_workout.completed_at == expected_completed_at

    history = api_client.get("/api/v1/workouts/history", headers=headers)
    assert history.status_code == 200
    history_rows = history.json()
    history_match = next(
        (row for row in history_rows if row["id"] == str(workout_id)),
        None,
    )
    assert history_match is not None, (
        "Completed workout should appear in GET /workouts/history."
    )
    assert history_match["status"] == "completed"
    assert history_match["completed_at"] == completed_at

    detail = api_client.get(
        f"/api/v1/workouts/{workout_id}",
        headers=headers,
    )
    assert detail.status_code == 200
    detail_body = detail.json()
    assert detail_body["status"] == "completed"
    assert detail_body["completed_at"] == completed_at
    detail_exercises = {
        exercise["id"]: exercise for exercise in detail_body["exercises"]
    }
    assert detail_exercises[first_exercise["id"]]["status"] == "completed"
    assert detail_exercises[skipped_exercise["id"]]["status"] == "skipped"
    assert detail_exercises[first_exercise["id"]]["sets"][0]["actual_reps"] == 10

    no_longer_current = api_client.get(
        "/api/v1/workouts/current",
        headers=headers,
    )
    assert no_longer_current.status_code == 404
    assert no_longer_current.json()["detail"] == "No workout in progress"

    missing_finish = api_client.post(
        f"/api/v1/workouts/{uuid.uuid4()}/finish",
        headers=headers,
    )
    assert missing_finish.status_code == 404
    post_finish_log = api_client.patch(
        f"/api/v1/workouts/sets/{first_set_id}",
        headers=headers,
        json={"actual_reps": 10},
    )
    assert post_finish_log.status_code == 422

    other_account = _register_and_login(api_client)
    try:
        foreign_detail = api_client.get(
            f"/api/v1/workouts/{workout_id}",
            headers={
                "Authorization": f"Bearer {other_account.access_token}"
            },
        )
        assert foreign_detail.status_code == 404, (
            "A different authenticated user must not view this workout."
        )
        foreign_start = api_client.post(
            "/api/v1/workouts/start",
            headers={
                "Authorization": f"Bearer {other_account.access_token}"
            },
            json={"program_day_id": str(workout_case.program_day_id)},
        )
        assert foreign_start.status_code == 404, (
            "A different user must not start another user's program day."
        )
    finally:
        _delete_account_by_email(other_account.email)
