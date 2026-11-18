# FORGE — Implement Workout HTTP Integration Phase 5C

Date: 2026-11-19

## 1. Objective and environment

Add opt-in, real-network FastAPI integration tests for workout lifecycle contracts against the dedicated local PostgreSQL database. The test target encoded by the harness is database `forge_workout_integration_test`, host `127.0.0.1`, port `5432`, driver `postgresql+psycopg`, with exactly one Alembic revision row equal to `a4f6c91d2e7b`.

The database and already-running FastAPI health results in the Phase 5B report are user-reported, not directly re-verified by Copilot. The harness launches and owns a separate Uvicorn subprocess on a dynamically assigned `127.0.0.1` port; it does not reuse, stop, or restart the user's server on port 8000.

## 2. Source files inspected

- API startup and health routes: [backend/app/main.py](../backend/app/main.py#L80), [backend/app/api/deps.py](../backend/app/api/deps.py#L20)
- Registration/login routes and password service: [backend/app/api/v1/auth.py](../backend/app/api/v1/auth.py#L39), [backend/app/services/auth.py](../backend/app/services/auth.py#L19)
- JWT creation/decoding and settings/database initialization: [backend/app/core/security.py](../backend/app/core/security.py#L50), [backend/app/core/config.py](../backend/app/core/config.py#L4), [backend/app/core/database.py](../backend/app/core/database.py#L7)
- Program route/service and response construction: [backend/app/api/v1/programs.py](../backend/app/api/v1/programs.py#L278), [backend/app/services/program_service.py](../backend/app/services/program_service.py#L311)
- Workout routes, service transitions, request/response schemas: [backend/app/api/v1/workouts.py](../backend/app/api/v1/workouts.py#L146), [backend/app/services/workout_service.py](../backend/app/services/workout_service.py#L66), [backend/app/schemas/workout.py](../backend/app/schemas/workout.py#L8)
- User, program/day/exercise, workout session/exercise/set, and muscle-group models: [backend/app/models/user.py](../backend/app/models/user.py#L18), [backend/app/models/training_program.py](../backend/app/models/training_program.py#L19), [backend/app/models/program_day.py](../backend/app/models/program_day.py#L16), [backend/app/models/program_exercise.py](../backend/app/models/program_exercise.py#L16), [backend/app/models/exercise.py](../backend/app/models/exercise.py#L16), [backend/app/models/muscle_group.py](../backend/app/models/muscle_group.py#L9), [backend/app/models/workout_session.py](../backend/app/models/workout_session.py#L26), [backend/app/models/workout_exercise.py](../backend/app/models/workout_exercise.py#L17), [backend/app/models/workout_set.py](../backend/app/models/workout_set.py#L21)
- Existing service-level fixtures and concurrency coverage: [backend/tests/test_workout_lifecycle.py](../backend/tests/test_workout_lifecycle.py#L58). Its in-memory fixture and optional PostgreSQL schema fixture do not exercise HTTP.
- Alembic configuration/environment and the active-workout migration: [backend/alembic.ini](../backend/alembic.ini#L89), [backend/alembic/env.py](../backend/alembic/env.py#L40), [backend/alembic/versions/a4f6c91d2e7b_enforce_one_active_workout_per_user.py](../backend/alembic/versions/a4f6c91d2e7b_enforce_one_active_workout_per_user.py#L14)
- Flutter workout request paths and JSON model expectations: [mobile/lib/features/workout/data/workout_repository.dart](../mobile/lib/features/workout/data/workout_repository.dart#L34), [mobile/lib/features/workout/data/workout_models.dart](../mobile/lib/features/workout/data/workout_models.dart#L17)
- Dependency manifests: [backend/requirements.txt](../backend/requirements.txt), [backend/requirements-dev.txt](../backend/requirements-dev.txt#L1)

The inspected auth flow creates a user through `POST /api/v1/auth/register`, then authenticates through `POST /api/v1/auth/login`. Workout setup requires an active `TrainingProgram`, a `ProgramDay`, and at least one joined `ProgramExercise`/`Exercise`; the test creates these prerequisites from ORM models and leaves workout creation/mutations to HTTP routes.

## 3. Exact files created or changed

- Created [backend/tests/test_workout_http_integration.py](../backend/tests/test_workout_http_integration.py#L1)
- Updated [backend/requirements-dev.txt](../backend/requirements-dev.txt#L3) to declare HTTPX `0.28.1` for the network client used by this test module.
- Created [audits/PREPARE-WORKOUT-INTEGRATION-PHASE5B-20261119.md](./PREPARE-WORKOUT-INTEGRATION-PHASE5B-20261119.md)
- Created this report.

No production Python, Flutter, Alembic, Docker Compose, `.env`, or `.env.local` files were changed.

## 4. Endpoint coverage matrix

| Contract | HTTP coverage | Persistence / expected result |
|---|---|---|
| Registration and login | `POST /api/v1/auth/register`, `POST /api/v1/auth/login` | Unique account is created; bearer token is used for subsequent network calls. |
| Authentication | `GET /api/v1/workouts/current` without a token and with a malformed token | Both return `401`; valid token with no active workout returns `404`. |
| Start workout | `POST /api/v1/workouts/start` | Returns `201` with the session, two pending exercises, and sets; session, exercises, and sets are queried from PostgreSQL. |
| Duplicate start / pending finish | Repeat start; finish while exercises remain pending | Returns `409` in each invalid state. |
| Current workout | `GET /api/v1/workouts/current` before and after start | Returns the active session while in progress; returns `404` after completion. |
| Log set | `PATCH /api/v1/workouts/sets/{workout_set_id}` | Checks response values and persisted reps, weight, RPE, completion time/state, and exercise state. |
| Skip exercise | `POST /api/v1/workouts/exercises/{workout_exercise_id}/skip` | Checks response and persisted `skipped` state. |
| Invalid transitions | Skip a completed exercise, log a skipped set, log after finish | Checks `422` responses. |
| Finish and retry | `POST /api/v1/workouts/{workout_id}/finish` | Concurrent HTTP finishes and a later retry return `200`, `completed`, and the same timestamp; PostgreSQL status/time are checked. |
| History and detail | `GET /api/v1/workouts/history`, `GET /api/v1/workouts/{workout_id}` | Checks completed summary/detail, nested exercise states, and logged set values. |
| Authorization / not found | Other registered user's detail/start requests; finish for unknown ID | Checks that foreign resources return `404` and unknown finish returns `404`. |

Coverage assertions are in [the authentication test](../backend/tests/test_workout_http_integration.py#L484) and [the lifecycle test](../backend/tests/test_workout_http_integration.py#L513).

## 5. Fixture setup and cleanup design

- `integration_target` performs opt-in, URL-shape, live `current_database()`, and Alembic revision checks before any test record or fixture data is created ([test_workout_http_integration.py](../backend/tests/test_workout_http_integration.py#L89)).
- `integration_server` starts a child Uvicorn process only after the parent preflight. The child repeats the database/revision checks before importing the application; the app receives the same explicit URL and an ephemeral test-only JWT signing key ([test_workout_http_integration.py](../backend/tests/test_workout_http_integration.py#L190)).
- Test accounts are registered and logged in through the real HTTP auth routes. Emails and passwords are generated per fixture; no real user credentials are used ([test_workout_http_integration.py](../backend/tests/test_workout_http_integration.py#L277)).
- The workout fixture inserts one uniquely named muscle group, two exercises, one active program, one program day, and two program exercises. The test then creates workout data exclusively through HTTP ([test_workout_http_integration.py](../backend/tests/test_workout_http_integration.py#L336)).
- Cleanup deletes only the fixture account's workout sessions/program hierarchy and the exact generated exercise/muscle-group IDs. Database foreign-key cascades remove child workout exercises/sets. The secondary test account is deleted by its unique generated email. There is no table truncation, database drop, schema drop, or global cleanup.
- The test server process is terminated only by its owning fixture. The user's separate FastAPI process is not targeted.

## 6. Safety guards implemented

- Tests skip when `FORGE_WORKOUT_HTTP_INTEGRATION` is absent and fail unless it is exactly `1`.
- An explicit `FORGE_WORKOUT_TEST_DATABASE_URL` is mandatory. The URL must parse as `postgresql+psycopg`, host `127.0.0.1`, port `5432`, database `forge_workout_integration_test`, with no URL query options. The harness never falls back to `DATABASE_URL`, `.env`, `.env.local`, development databases, or cloud hosts.
- Before writes, the parent connects read-only and requires `current_database()` to match the approved database and `public.alembic_version` to contain exactly `a4f6c91d2e7b`. The server subprocess repeats these checks using its own explicit connection environment.
- The test module fails if application config/database modules were imported before the guard, which is why the supplied command runs this module alone.
- The URL and JWT key are never printed by harness code; database preflight errors are sanitized, HTTP server output is suppressed, and tokens are excluded from dataclass representations.
- `PGOPTIONS` is cleared, application settings required for startup are provided explicitly, and only loopback HTTPX requests are made.
- The test does not run Alembic or create/drop schema objects.

## 7. Confirmation of no production database changes

Copilot did not connect to a database or execute tests, migrations, inserts, updates, deletes, truncations, schema operations, or database health requests. No production/development connection settings were changed. Therefore Copilot made no changes to `forge`, `forge_workout_test`, or the reported integration database.

## 8. Test implementation summary

The new module uses HTTPX `Client` requests over TCP to a child Uvicorn server bound to `127.0.0.1` on a dynamically selected port. It does not use `ASGITransport`, `TestClient`, dependency overrides, mocked route calls, or the Flutter fake Dio adapter. The lifecycle test uses two independent HTTPX clients and a barrier for concurrent Finish requests. The only polling delay is the short readiness wait while the child server starts; lifecycle actions use no sleeps.

## 9. Static validation results

- Passed syntax-only compilation with the project virtualenv's Python 3.13: `backend\.venv\Scripts\python.exe -m py_compile backend\tests\test_workout_http_integration.py` from the repository root.
- The plain `python` command resolves to Python 3.9.13; the project virtualenv is Python 3.13.15 and has the application/pytest dependencies, but HTTPX is not installed in that virtualenv yet.
- `git diff --check` passed for the tracked dependency edit; a trailing-whitespace search found no matches in the new test module.
- HTTPX `0.28.1` is now declared in `requirements-dev.txt`; its installation in the project virtualenv remains pending.
- No pytest collection or test execution was performed.

## 10. Tests NOT executed

- `backend/tests/test_workout_http_integration.py` was not run, collected, or connected to PostgreSQL.
- No existing tests were run.
- No Alembic commands, migrations, database health checks, or database writes were run by Copilot.

## 11. Known gaps and blockers

- **P0:** None identified by static inspection.
- **P1:** Human safety review is still required before running this mutating integration module. Execution also requires explicitly supplying the approved test-database URL and installing the updated dev requirements into the project virtualenv (HTTPX is currently missing there).
- **P1:** Runtime behavior, database connectivity, actual response serialization, cleanup, and concurrency assertions remain unverified until the human-approved test run.
- **P2:** This module intentionally fails if application database/config modules have already loaded, so it must run alone rather than in a combined pytest invocation.

## 12. Exact safe execution commands for human review

Review the target first. From Windows PowerShell, use the same Python 3.10+ environment that successfully runs the backend. The secure prompt avoids putting the URL in the command text or PowerShell history:

```powershell
Set-Location 'C:\Projects\forge\backend'
.\.venv\Scripts\python.exe --version
.\.venv\Scripts\python.exe -c "import sys; assert sys.version_info >= (3, 10), 'Python 3.10+ is required'"
if ($LASTEXITCODE -ne 0) { throw 'Select the supported backend Python environment before continuing.' }

# Run only after reviewing the dependency change; HTTPX is missing from this venv.
.\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
if ($LASTEXITCODE -ne 0) { throw 'Installing the backend development requirements failed.' }

$testExitCode = 1
$secureUrl = Read-Host 'Approved PostgreSQL test URL (URL-encode special credential characters)' -AsSecureString
$urlPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureUrl)
try {
    $env:FORGE_WORKOUT_HTTP_INTEGRATION = '1'
    $env:FORGE_WORKOUT_TEST_DATABASE_URL = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($urlPointer)
    .\.venv\Scripts\python.exe -m pytest -q tests\test_workout_http_integration.py
    $testExitCode = $LASTEXITCODE
}
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($urlPointer)
    Remove-Item Env:FORGE_WORKOUT_HTTP_INTEGRATION -ErrorAction SilentlyContinue
    Remove-Item Env:FORGE_WORKOUT_TEST_DATABASE_URL -ErrorAction SilentlyContinue
}
if ($testExitCode -ne 0) { throw "Integration test process exited with code $testExitCode." }
```

The prompted URL must be in the form `postgresql+psycopg://<user>:<password>@127.0.0.1:5432/forge_workout_integration_test`; encode any URL-reserved credential characters. Do not use a URL for `forge`, `forge_workout_test`, Neon, Render, or any production database. Do not execute until the report and cleanup plan have been reviewed.

## 13. Readiness verdict

**NOT READY FOR TEST EXECUTION** — implementation and static syntax validation are complete, but the explicit human safety review and runtime validation have not occurred. Do not interpret this verdict as evidence that the integration tests passed.
