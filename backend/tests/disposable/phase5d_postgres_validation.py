"""Run only with explicit approval of the recorded disposable Docker target."""

import argparse
from contextlib import contextmanager
from dataclasses import replace
import json
import os
from pathlib import Path
import runpy
import secrets
import socket
from statistics import median
import subprocess
import sys
from time import perf_counter, sleep
import traceback
from types import ModuleType, SimpleNamespace
from unittest.mock import patch
from uuid import uuid4

from alembic import command
from alembic.config import Config
from alembic.script import ScriptDirectory
from fastapi import FastAPI
from fastapi.testclient import TestClient
import psycopg
from psycopg import sql
import sqlalchemy as sa
from sqlalchemy.orm import DeclarativeBase, Session


BACKEND = Path(__file__).resolve().parents[2]
NAME = "forge-phase5d-pg-20261119-67c2"
ROLE = "phase5d_runner_67c2"
MAIN = "phase5d_main_67c2"
DOWN = "phase5d_downgrade_67c2"
PORT = 55432
HOST = "127.0.0.1"
PARENT = "a4f6c91d2e7b"
HEAD = "7c92e4f1b6a8"
LABEL = "forge.validation.phase5d"
ENDPOINT = "npipe:////./pipe/dockerDesktopLinuxEngine"
PGDATA = "/var/lib/postgresql/data"
CHECK = "ck_program_day_duration"
IDENTITY = """
    SELECT current_database(), current_user, current_schema(),
           (pg_control_system()).system_identifier::text,
           inet_server_addr()::text, inet_server_port()
"""


def require_disposable_database(db):
    if db not in (MAIN, DOWN):
        raise RuntimeError("Database is outside the disposable allowlist")


class DisposableRun:
    def __init__(self, docker):
        self.docker = docker
        self.label = uuid4().hex
        self.password = secrets.token_hex(24)
        self.cid = None
        self.fingerprint = None
        self.engines = []

    def cli(self, *args, env=None, timeout=45, check=True):
        return subprocess.run(
            [self.docker, "--host", ENDPOINT, *args],
            env=env, timeout=timeout, check=check, capture_output=True, text=True,
        )

    def inspect(self):
        if not self.cid:
            raise RuntimeError("No disposable Docker container ID was recorded")
        raw = self.cli(
            "inspect", "--type", "container", "--format",
            '{{json .Id}} {{json .Name}} {{json .Config.Labels}} '
            '{{json .HostConfig.Tmpfs}} {{json .NetworkSettings.Ports}} '
            '{{json .State.Running}} {{json .Mounts}}',
            self.cid,
        ).stdout.strip()
        decoder = json.JSONDecoder()
        values = []
        while raw:
            value, end = decoder.raw_decode(raw)
            values.append(value)
            raw = raw[end:].lstrip()
        cid, name, labels, tmpfs, ports, running, mounts = values
        if cid != self.cid or name != f"/{NAME}" or labels.get(LABEL) != self.label:
            raise RuntimeError("Docker container identity mismatch")
        return tmpfs or {}, ports or {}, running, mounts

    def verify_container(self):
        tmpfs, ports, running, mounts = self.inspect()
        if running is not True or PGDATA not in tmpfs:
            raise RuntimeError("Disposable container must be running with tmpfs PostgreSQL data")
        if ports != {"5432/tcp": [{"HostIp": HOST, "HostPort": str(PORT)}]}:
            raise RuntimeError("Disposable container has an unexpected port binding")
        if any(item["Type"] != "tmpfs" for item in mounts):
            raise RuntimeError("Disposable container has a non-tmpfs mount")

    def start(self):
        if self.cli("version", "--format", "{{.Server.Os}}").stdout.strip() != "linux":
            raise RuntimeError("Disposable validation requires the local Linux Docker engine")
        if self.cli("ps", "-a", "--filter", f"name=^/{NAME}$", "-q").stdout.strip():
            raise RuntimeError("Disposable container name is already in use")
        self.cli("image", "inspect", "--format", "{{.Id}}", "postgres:16")
        with socket.socket() as probe:
            probe.setsockopt(socket.SOL_SOCKET, socket.SO_EXCLUSIVEADDRUSE, 1)
            probe.bind((HOST, PORT))
        keep = ("SYSTEMROOT", "WINDIR", "PATH", "USERPROFILE", "TEMP", "TMP", "APPDATA", "LOCALAPPDATA")
        env = {key: os.environ[key] for key in keep if key in os.environ}
        env["POSTGRES_PASSWORD"] = self.password
        started = self.cli(
            "run", "--detach", "--pull", "never", "--name", NAME,
            "--label", f"{LABEL}={self.label}", "--publish", f"{HOST}:{PORT}:5432",
            "--tmpfs", f"{PGDATA}:rw,size=384m",
            "--env", f"POSTGRES_USER={ROLE}", "--env", f"POSTGRES_DB={MAIN}",
            "--env", "POSTGRES_PASSWORD", "postgres:16",
            env=env,
        )
        self.cid = started.stdout.strip()
        self.verify_container()
        for _ in range(40):
            ready = self.cli("exec", self.cid, "pg_isready", "-h", HOST, "-U", ROLE, "-d", MAIN, check=False)
            if ready.returncode == 0:
                break
            sleep(1)
        else:
            raise RuntimeError("Disposable PostgreSQL did not become ready")
        identity = self.cli(
            "exec", self.cid, "psql", "-XAt", "-v", "ON_ERROR_STOP=1", "-U", ROLE, "-d", MAIN,
            "-c", "SELECT current_database(), current_user, (pg_control_system()).system_identifier",
        ).stdout.strip().split("|")
        if len(identity) != 3 or identity[:2] != [MAIN, ROLE] or not identity[2].isdigit():
            raise RuntimeError("Could not verify the PostgreSQL identity inside the disposable container")
        self.fingerprint = identity
        print(f"ISOLATION container={self.cid[:12]} label={self.label} endpoint={HOST}:{PORT} "
              f"role={ROLE} dbs={MAIN},{DOWN} server_id={self.fingerprint[2]}", flush=True)

    def credentials(self, db):
        require_disposable_database(db)
        return dict(host=HOST, hostaddr=HOST, port=PORT, dbname=db, user=ROLE,
                    password=self.password, connect_timeout=5)

    def verify_server(self, driver, db):
        require_disposable_database(db)
        if self.fingerprint is None:
            raise RuntimeError("No verified disposable PostgreSQL fingerprint was recorded")
        with driver.cursor() as cursor:
            cursor.execute(IDENTITY)
            identity = cursor.fetchone()
        if identity is None:
            raise RuntimeError("PostgreSQL returned no server identity")
        database, role, schema, fingerprint, address, port = identity
        if not address or (database, role, schema, fingerprint, port) != (
            db, ROLE, "public", self.fingerprint[2], 5432,
        ):
            raise RuntimeError("PostgreSQL connection identity does not match the disposable target")

    def create_second_database(self):
        self.verify_container()
        with psycopg.connect(**self.credentials(MAIN), autocommit=True) as driver:
            self.verify_server(driver, MAIN)
            driver.execute(sql.SQL("CREATE DATABASE {}").format(sql.Identifier(DOWN)))

    def engine(self, db):
        engine = sa.create_engine(
            self.url(db), connect_args={"hostaddr": HOST, "connect_timeout": 5},
            hide_parameters=True,
        )
        self.engines.append(engine)

        @sa.event.listens_for(engine, "begin")
        def verify_before_transaction(connection):
            self.verify_server(connection.connection.driver_connection, db)

        return engine

    def url(self, db):
        require_disposable_database(db)
        return sa.URL.create("postgresql+psycopg", ROLE, self.password, HOST, PORT, db)

    def close(self):
        for engine in self.engines:
            engine.dispose()
        if self.cid:
            self.inspect()
            self.cli("rm", "-f", self.cid)
            print(f"CLEANUP removed disposable container {self.cid[:12]} and its tmpfs", flush=True)


def install_config(run):
    sys.path.insert(0, str(BACKEND))

    class Base(DeclarativeBase):
        pass

    def unexpected_db():
        raise AssertionError("The test must supply its verified session factory")

    config = ModuleType("app.core.config")
    config.settings = SimpleNamespace(database_url=run.url(MAIN).render_as_string(hide_password=False))
    database = ModuleType("app.core.database")
    database.Base = Base
    database.get_db = unexpected_db
    sys.modules[config.__name__] = config
    sys.modules[database.__name__] = database
    return config.settings


def migration_config():
    cfg = Config()
    cfg.set_main_option("script_location", str(BACKEND / "alembic"))
    return cfg


def migrate(run, settings, engine, db, direction, target):
    run.verify_container()
    url = run.url(db)
    if engine not in run.engines or engine.url != url:
        raise RuntimeError("Migration engine does not match the verified disposable database")
    settings.database_url = url.render_as_string(hide_password=False)
    with patch("sqlalchemy.engine_from_config", return_value=engine):
        getattr(command, direction)(migration_config(), target)


def schema_state(engine):
    with engine.connect() as db:
        revision = db.scalar(sa.text("SELECT version_num FROM alembic_version"))
        constraints = db.execute(sa.text("""
            SELECT pg_get_constraintdef(oid), convalidated
            FROM pg_constraint
            WHERE conrelid = 'public.program_days'::regclass AND conname = :name
        """), {"name": CHECK}).all()
        if len(constraints) != 1 or not constraints[0][1]:
            raise RuntimeError("Expected a validated duration constraint before proceeding")
        estimates = db.execute(sa.text(
            "SELECT estimated_duration_minutes FROM program_days ORDER BY estimated_duration_minutes"
        )).scalars().all()
        return revision, constraints[0][0], estimates


def boundary_checks(run, engine, allowed, blocked, persist=None):
    from app.models import ProgramDay, TrainingProgram, User

    run.verify_container()
    with engine.connect() as db:
        tx = db.begin()
        user_id, program_id = uuid4(), uuid4()
        db.execute(sa.insert(User).values(id=user_id, email=f"{user_id}@example.test", password_hash="fixture"))
        db.execute(sa.insert(TrainingProgram).values(
            id=program_id, user_id=user_id, version_number=1, name="CHECK fixture",
            goal="strength", generator_version="test", status="active",
        ))
        for estimate in (*allowed, *blocked):
            try:
                with db.begin_nested():
                    db.execute(sa.insert(ProgramDay).values(
                        id=uuid4(), program_id=program_id, day_of_week=1, day_order=1,
                        name="CHECK fixture", estimated_duration_minutes=estimate,
                    ))
                    if estimate in allowed and estimate != persist:
                        db.execute(sa.delete(ProgramDay).where(ProgramDay.program_id == program_id))
            except sa.exc.IntegrityError as exc:
                if estimate not in blocked or exc.orig.diag.constraint_name != CHECK:
                    raise RuntimeError("Unexpected database failure during duration boundary check") from exc
            else:
                if estimate not in allowed:
                    raise RuntimeError(f"Database accepted invalid duration estimate {estimate}")
        if persist is None:
            tx.rollback()
        else:
            tx.commit()
    print(f"CHECK accepted={allowed} rejected={blocked} persisted={persist}", flush=True)


def migration_cases(run, settings, main, down):
    from alembic.runtime.migration import MigrationContext

    with main.connect() as db:
        if MigrationContext.configure(db).get_current_revision() is not None:
            raise RuntimeError("Disposable main database already has an Alembic revision")
    script = ScriptDirectory.from_config(migration_config())
    if script.get_heads() != [HEAD] or script.get_revision(HEAD).down_revision != PARENT:
        raise RuntimeError("Alembic graph does not match the approved validation revisions")
    print(f"GRAPH empty -> {PARENT} -> {HEAD}, revisions={len(list(script.walk_revisions()))}", flush=True)
    migrate(run, settings, main, MAIN, "upgrade", PARENT)
    if schema_state(main)[0] != PARENT:
        raise RuntimeError("Disposable database did not reach the expected parent revision")
    boundary_checks(run, main, [15], [12], persist=15)
    parent_state = schema_state(main)
    migrate(run, settings, main, MAIN, "upgrade", HEAD)
    upgraded = schema_state(main)
    if upgraded[0] != HEAD or upgraded[2] != [15] or upgraded[1] == parent_state[1]:
        raise RuntimeError("Upgrade did not preserve the fixture and update the duration constraint")
    print(f"UPGRADE parent={parent_state} head={upgraded}", flush=True)
    boundary_checks(run, main, [1, 12, 14, 15, 240], [0, -1, 241])
    migrate(run, settings, main, MAIN, "downgrade", PARENT)
    if schema_state(main) != parent_state:
        raise RuntimeError("Downgrade did not restore the expected parent schema and fixture")
    boundary_checks(run, main, [15, 240], [12, 14])
    print(f"DOWNGRADE compatible restored={parent_state}", flush=True)
    migrate(run, settings, main, MAIN, "upgrade", HEAD)

    migrate(run, settings, down, DOWN, "upgrade", HEAD)
    boundary_checks(run, down, [12], [], persist=12)
    boundary_checks(run, down, [14], [], persist=14)
    before = schema_state(down)
    try:
        migrate(run, settings, down, DOWN, "downgrade", PARENT)
    except sa.exc.IntegrityError as exc:
        if exc.orig.diag.constraint_name != CHECK or exc.orig.sqlstate != "23514":
            raise RuntimeError("Downgrade failed for a reason other than the duration check") from exc
    else:
        raise AssertionError("Downgrade accepted existing short estimates")
    if schema_state(down) != before or before[2] != [12, 14]:
        raise RuntimeError("Failed downgrade did not preserve the expected schema and fixtures")
    print(f"DOWNGRADE blocked sqlstate=23514 and restored state={before}", flush=True)


@contextmanager
def writing_session(run, engine):
    run.verify_container()
    with Session(engine) as db:
        yield db
        db.commit()


def add_catalog(db, entries):
    from app.models import Equipment, Exercise, ExerciseEquipment, ExerciseSecondaryMuscle, MuscleGroup

    equipment = {item.code: item for item in db.scalars(sa.select(Equipment))}
    muscles = {item.code: item for item in db.scalars(sa.select(MuscleGroup))}
    for code in sorted({code for entry in entries for code in entry.equipment} | {"FULL_GYM"}):
        if code not in equipment:
            equipment[code] = Equipment(code=code, name=code)
            db.add(equipment[code])
    for code in sorted({entry.muscle for entry in entries} | {m for e in entries for m in e.secondary}):
        if code not in muscles:
            muscles[code] = MuscleGroup(code=code, name=code, region="upper")
            db.add(muscles[code])
    db.flush()
    for entry in entries:
        exercise = Exercise(primary_muscle_id=muscles[entry.muscle].id, **vars(entry.exercise))
        db.add(exercise)
        db.flush()
        db.add_all([
            ExerciseEquipment(exercise_id=exercise.id, equipment_id=equipment[code].id)
            for code in entry.equipment
        ])
        db.add_all([
            ExerciseSecondaryMuscle(
                exercise_id=exercise.id, muscle_group_id=muscles[muscle].id, contribution_weight=weight,
            )
            for muscle, weight in entry.secondary.items()
        ])


def add_user(db, days, minutes, goal, experience, equipment, *, boxing=False, priorities=None):
    from app.models import (
        Equipment, Goal, MuscleGroup, SportActivity, TrainingDay, TrainingPreference,
        User, UserEquipment, UserMusclePriority, UserProfile,
    )

    user = User(email=f"{uuid4()}@example.test", password_hash="fixture")
    db.add(user)
    db.flush()
    user_id = user.id
    equipment_id = db.scalar(sa.select(Equipment.id).where(Equipment.code == equipment))
    db.add_all([
        UserProfile(user_id=user_id, experience_level=experience),
        Goal(user_id=user_id, primary_goal=goal),
        TrainingPreference(user_id=user_id, days_per_week=len(days), session_duration_minutes=minutes),
        UserEquipment(user_id=user_id, equipment_id=equipment_id),
        *(TrainingDay(user_id=user_id, day_of_week=day) for day in days),
    ])
    if boxing:
        db.add(SportActivity(user_id=user_id, sport_type="boxing", day_of_week=1,
                             duration_minutes=60, intensity="high"))
    for code, priority in (priorities or {}).items():
        muscle_id = db.scalar(sa.select(MuscleGroup.id).where(MuscleGroup.code == code))
        db.add(UserMusclePriority(user_id=user_id, muscle_group_id=muscle_id, priority=priority))
    return user_id


def http_cases(run, engine):
    from app.api.v1 import programs, workouts
    from app.generator.builder import build_program_plan
    from app.generator.context import build_generator_context
    from app.generator.validator import validate_program
    from app.models import Exercise, ProgramDay, TrainingPreference, TrainingProgram, User, WorkoutSet
    from app.services import program_service

    suite = runpy.run_path(str(BACKEND / "tests/generator/test_program_integration_validation.py"))
    catalog = suite["synthetic_catalog"]()
    subset = [replace(entry, secondary={}) for entry in catalog if entry.muscle in {"CHEST", "BACK"}
              and entry.equipment == {"BODYWEIGHT"}]
    subset_ids = {entry.exercise.id for entry in subset}
    with writing_session(run, engine) as db:
        add_catalog(db, subset)
        user_id = add_user(db, (1,), 30, "strength", "beginner", "BODYWEIGHT", boxing=True)

    app = FastAPI()
    app.include_router(programs.router, prefix="/api/v1")
    app.include_router(workouts.router, prefix="/api/v1")

    def test_session():
        with Session(engine) as db:
            yield db

    def test_user():
        return SimpleNamespace(id=user_id, training_setup_revision=1)

    app.dependency_overrides[programs.get_db] = test_session
    app.dependency_overrides[programs.get_current_user] = test_user

    def mutate_request(client, method, url, **kwargs):
        run.verify_container()
        return client.request(method, f"/api/v1{url}", **kwargs)

    def change_setup(nominal, rest):
        with writing_session(run, engine) as db:
            preference = db.scalar(sa.select(TrainingPreference).where(TrainingPreference.user_id == user_id))
            preference.session_duration_minutes = nominal
            for exercise in db.scalars(sa.select(Exercise)):
                exercise.default_rest_seconds = rest

    def build_and_check(entries):
        with Session(engine) as db:
            context = build_generator_context(db, db.get(User, user_id))
            result = build_program_plan(db, context)
            validation = validate_program(context, result)
            assert validation.is_valid, validation.issues
        counts = suite["verify_program"](context, entries, result, validation)
        return result, counts

    with TestClient(app, raise_server_exceptions=False) as client:
        for nominal, rest, estimate, sets in ((30, 60, 12, 1), (90, 30, 14, 2), (90, 60, 15, 2)):
            change_setup(nominal, rest)
            entries = [
                replace(entry, exercise=SimpleNamespace(**{**vars(entry.exercise), "default_rest_seconds": rest}))
                for entry in subset
            ]
            result, (physical, targets, actual) = build_and_check(entries)
            assert targets == actual == {"CHEST": sets, "BACK": sets} and physical == sets * 2
            generated = mutate_request(client, "POST", "/programs/generate")
            assert generated.status_code == 201, (estimate, generated.status_code, generated.text)
            detail = client.get("/api/v1/programs/current").json()
            assert detail["id"] == generated.json()["id"]
            day = detail["days"][0]
            assert day["estimated_duration_minutes"] == result.fitted_program.sessions[0].estimated_duration_minutes == estimate
            assert {(e["sets"], e["min_reps"], e["max_reps"], e["rest_seconds"]) for e in day["exercises"]} == {
                (sets, 8, 12, rest)
            } and len(day["exercises"]) == 2
            print(f"HTTP 201/200 estimate={estimate} sets={physical} targets={targets} rest={rest}", flush=True)

        def saved_programs():
            with Session(engine) as db:
                return db.execute(sa.select(TrainingProgram.id, TrainingProgram.status).where(
                    TrainingProgram.user_id == user_id
                ).order_by(TrainingProgram.version_number)).all()

        snapshot = saved_programs()
        assert [row.status for row in snapshot] == ["archived", "archived", "active"]
        change_setup(15, 60)
        rejected = mutate_request(client, "POST", "/programs/generate")
        assert rejected.status_code == 422 and "within 10 minutes" in rejected.json()["detail"]
        assert client.get("/api/v1/programs/current").json() == detail and saved_programs() == snapshot
        print("HTTP 422 fitter infeasible; active program unchanged", flush=True)

        change_setup(90, 60)
        archived = []
        constraint = []

        def fail_insert(_mapper, connection, instance):
            archived.append(connection.scalar(sa.select(TrainingProgram.status).where(
                TrainingProgram.id == snapshot[-1].id
            )))
            instance.estimated_duration_minutes = 0

        def observe_error(context):
            constraint.append(context.original_exception.diag.constraint_name)

        sa.event.listen(ProgramDay, "before_insert", fail_insert)
        sa.event.listen(engine, "handle_error", observe_error)
        try:
            broken = mutate_request(client, "POST", "/programs/generate")
        finally:
            sa.event.remove(ProgramDay, "before_insert", fail_insert)
            sa.event.remove(engine, "handle_error", observe_error)
        assert broken.status_code == 500 and broken.text == "Internal Server Error"
        assert archived == ["archived"] and constraint == [CHECK]
        assert client.get("/api/v1/programs/current").json() == detail and saved_programs() == snapshot
        print("HTTP 500 CHECK failure after archive; PostgreSQL rollback restored active program", flush=True)

        started = mutate_request(client, "POST", "/workouts/start", json={"program_day_id": day["id"]})
        assert started.status_code == 201, (started.status_code, started.text)
        workout = started.json()
        assert workout["training_program_id"] == detail["id"]
        set_ids = []
        for planned, active in zip(day["exercises"], workout["exercises"], strict=True):
            assert active["program_exercise_id"] == planned["id"]
            assert (active["target_sets"], active["target_min_reps"], active["target_max_reps"],
                    active["target_rest_seconds"]) == (planned["sets"], planned["min_reps"],
                                                      planned["max_reps"], planned["rest_seconds"])
            assert len(active["sets"]) == planned["sets"]
            for item in active["sets"]:
                log = mutate_request(client, "PATCH", f"/workouts/sets/{item['id']}",
                                     json={"actual_reps": 10, "rpe": 8})
                assert log.status_code == 200 and log.json()["is_completed"]
                set_ids.append(item["id"])
        path = f"/workouts/{workout['id']}"
        finish = mutate_request(client, "POST", f"{path}/finish")
        again = mutate_request(client, "POST", f"{path}/finish")
        assert finish.status_code == again.status_code == 200
        assert finish.json() == again.json() == client.get(f"/api/v1{path}").json()
        assert finish.json()["status"] == "completed"
        with Session(engine) as db:
            sets = db.scalars(sa.select(WorkoutSet)).all()
            assert sorted(str(item.id) for item in sets) == sorted(set_ids)
            assert all(item.actual_reps == 10 and item.rpe == 8 for item in sets)
        print(f"WORKOUT start=201 log={len(set_ids)}x200 finish=200 retry=200 DB reread matched", flush=True)

        remaining = [entry for entry in catalog if entry.exercise.id not in subset_ids]
        with writing_session(run, engine) as db:
            add_catalog(db, remaining)
        adjusted = [*entries, *remaining]
        for days in ((1, 3, 5, 7), tuple(range(1, 8))):
            with writing_session(run, engine) as db:
                user_id = add_user(db, days, 120, "hybrid", "advanced", "FULL_GYM",
                                   priorities={"CHEST": "high", "TRICEPS": "maintenance"})
            result, (physical, targets, actual) = build_and_check(adjusted)
            print(f"GENERATOR days={len(days)} target={sum(targets.values())} physical={physical} "
                  f"effective={sum(actual.values())} recovery={result.split_plan.total_recovery_conflict_score}",
                  flush=True)
            benchmark(client, run, engine, program_service, len(days))

    with writing_session(run, engine) as db:
        # Sparse targets prove the H1 cap against actual PostgreSQL catalog reads.
        user_id = add_user(db, (1, 3, 5), 15, "strength", "beginner", "BODYWEIGHT",
                           priorities={"CHEST": "high", "BACK": "normal"})
    from app.generator.distribution import distribute_volume
    from app.generator.split import generate_split_plan
    from app.generator.volume import calculate_volume_plan
    with Session(engine) as db:
        context = build_generator_context(db, db.get(User, user_id))
        volume = calculate_volume_plan(context)
        distribution = distribute_volume(context, volume, generate_split_plan(context))
        for muscle, target in volume.targets.items():
            values = distribution.allocations_for_muscle(muscle)
            assert len(values) == sum(item.target_effective_sets for item in values) == target.target_effective_sets == 1
    print(f"H1 sparse targets validated per muscle ({len(volume.targets)} muscles at 1/1 exposure)", flush=True)


def benchmark(client, run, engine, service, days):
    real_build = service.build_program_plan
    build_times, query_times, total_times = [], [], []

    def timed_build(*args, **kwargs):
        start = perf_counter()
        result = real_build(*args, **kwargs)
        build_times.append((perf_counter() - start) * 1000)
        return result

    def before_cursor(_conn, _cursor, _statement, _params, context, _many):
        context.validation_started = perf_counter()

    def after_cursor(_conn, _cursor, _statement, _params, context, _many):
        query_times.append((perf_counter() - context.validation_started) * 1000)

    sa.event.listen(engine, "before_cursor_execute", before_cursor)
    sa.event.listen(engine, "after_cursor_execute", after_cursor)
    try:
        with patch.object(service, "build_program_plan", side_effect=timed_build):
            for index in range(8):
                run.verify_container()
                start = perf_counter()
                response = client.post("/api/v1/programs/generate")
                total = (perf_counter() - start) * 1000
                assert response.status_code == 201, (days, response.status_code, response.text)
                if index >= 2:
                    total_times.append((total, build_times[-1], sum(query_times)))
                query_times.clear()
    finally:
        sa.event.remove(engine, "before_cursor_execute", before_cursor)
        sa.event.remove(engine, "after_cursor_execute", after_cursor)
    summary = [tuple(round(metric(values), 2) for metric in (median, max))
               for values in zip(*total_times, strict=True)]
    print(f"BENCH days={days} median/max ms HTTP={summary[0]} build={summary[1]} SQL_cursor={summary[2]}",
          flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--docker", required=True)
    parser.add_argument("--approved-target", required=True, choices=[NAME])
    args = parser.parse_args()
    for key in tuple(os.environ):
        if key.startswith("PG"):
            os.environ.pop(key, None)
    run = DisposableRun(args.docker)
    result = 0
    try:
        run.start()
        settings = install_config(run)
        run.create_second_database()
        migration_cases(run, settings, run.engine(MAIN), run.engine(DOWN))
        http_cases(run, run.engine(MAIN))
        print("VALIDATION PASSED", flush=True)
    except Exception:
        print(traceback.format_exc().replace(run.password, "<redacted>"), file=sys.stderr)
        result = 1
    finally:
        try:
            run.close()
        except Exception:
            print(traceback.format_exc().replace(run.password, "<redacted>"), file=sys.stderr)
            result = 1
    return result


if __name__ == "__main__":
    raise SystemExit(main())
