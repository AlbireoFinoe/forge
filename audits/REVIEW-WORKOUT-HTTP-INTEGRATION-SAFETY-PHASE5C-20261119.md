# FORGE Phase 5C — Final HTTP Integration Test Safety Review

Date: 2026-11-19

## 1. Files inspected

- [backend/tests/test_workout_http_integration.py](../backend/tests/test_workout_http_integration.py#L1)
- [backend/requirements-dev.txt](../backend/requirements-dev.txt#L1)
- [audits/IMPLEMENT-WORKOUT-HTTP-INTEGRATION-PHASE5C-20261119.md](./IMPLEMENT-WORKOUT-HTTP-INTEGRATION-PHASE5C-20261119.md)
- [backend/app/core/config.py](../backend/app/core/config.py#L4), [backend/app/core/database.py](../backend/app/core/database.py#L7), [backend/app/core/security.py](../backend/app/core/security.py#L50), [backend/app/api/deps.py](../backend/app/api/deps.py#L20)
- [backend/app/api/v1/auth.py](../backend/app/api/v1/auth.py#L39), [backend/app/api/v1/workouts.py](../backend/app/api/v1/workouts.py#L151), [backend/app/api/v1/programs.py](../backend/app/api/v1/programs.py#L278)
- [backend/app/services/auth.py](../backend/app/services/auth.py#L19), [backend/app/services/workout_service.py](../backend/app/services/workout_service.py#L85), [backend/app/services/program_service.py](../backend/app/services/program_service.py#L311)
- [backend/app/schemas/auth.py](../backend/app/schemas/auth.py#L7), [backend/app/schemas/workout.py](../backend/app/schemas/workout.py#L8)
- [backend/app/models/user.py](../backend/app/models/user.py#L18), [backend/app/models/training_program.py](../backend/app/models/training_program.py#L19), [backend/app/models/program_day.py](../backend/app/models/program_day.py#L16), [backend/app/models/program_exercise.py](../backend/app/models/program_exercise.py#L16), [backend/app/models/exercise.py](../backend/app/models/exercise.py#L16), [backend/app/models/muscle_group.py](../backend/app/models/muscle_group.py#L9), [backend/app/models/workout_session.py](../backend/app/models/workout_session.py#L26), [backend/app/models/workout_exercise.py](../backend/app/models/workout_exercise.py#L17), [backend/app/models/workout_set.py](../backend/app/models/workout_set.py#L21)
- [backend/alembic.ini](../backend/alembic.ini#L89), [backend/alembic/env.py](../backend/alembic/env.py#L40), [backend/alembic/versions/a4f6c91d2e7b_enforce_one_active_workout_per_user.py](../backend/alembic/versions/a4f6c91d2e7b_enforce_one_active_workout_per_user.py#L14)
- [backend/tests/test_workout_lifecycle.py](../backend/tests/test_workout_lifecycle.py#L58), [backend/requirements.txt](../backend/requirements.txt)

The current branch was confirmed as `test/workout-integration-phase5`. No production code, test code, configuration, dependency, or database was changed in this review. The only file created was this requested review report.

## 2. Database target safety analysis

### Guards verified

- The session fixture skips unless `FORGE_WORKOUT_HTTP_INTEGRATION` is set and fails unless it is exactly `1` ([test module](../backend/tests/test_workout_http_integration.py#L89)).
- `FORGE_WORKOUT_TEST_DATABASE_URL` is mandatory. The parsed URL is restricted to driver `postgresql+psycopg`, host `127.0.0.1`, port `5432`, database `forge_workout_integration_test`, and no URL query parameters ([test module](../backend/tests/test_workout_http_integration.py#L108)).
- Before test records are created, the parent preflight queries `current_database()` and exactly the rows in `public.alembic_version`; it requires the exact database name and only revision `a4f6c91d2e7b` ([test module](../backend/tests/test_workout_http_integration.py#L139)).
- The child bootstrap repeats the same database/revision checks before calling `uvicorn.run` and importing `app.main` ([test module](../backend/tests/test_workout_http_integration.py#L29)).
- Missing opt-in or the explicit test URL does not select `DATABASE_URL` as a fallback. The application config does load `.env`, but the harness sets `DATABASE_URL` and the JWT settings explicitly in the parent and child before application imports. The module also fails if app config/database modules were already imported ([test module](../backend/tests/test_workout_http_integration.py#L102), [environment setup](../backend/tests/test_workout_http_integration.py#L177)).
- The validation order is appropriate for application imports and test-data writes: URL/connection/revision preflight, child-server database preflight, server readiness, then HTTP account/program setup.

### P1 — Inherited libpq variables can bypass the loopback host check

The URL parser verifies the URL's `host`, but psycopg uses libpq and the preflight connection is created without pinning `hostaddr`. The parent environment is not sanitized before the preflight, and the child environment starts with `os.environ.copy()`; only `PGOPTIONS` is removed. An inherited `PGHOSTADDR` can supply a connection address independently of the URL's `host=127.0.0.1`. Related service variables such as `PGSERVICE`/`PGSERVICEFILE` are also inherited. The database-name and revision checks reduce risk, but they do not prove that the server reached was local: a different server with a database of the same name/revision could pass and receive writes.

This makes the current host guard incomplete under an inherited or injected PostgreSQL environment. It is not evidence that such a variable is currently set.

**Required before execution:** sanitize libpq connection variables before both parent preflight and child startup, and use an allowlisted child environment. At minimum reject/remove `PGHOSTADDR`, `PGSERVICE`, `PGSERVICEFILE`, and inherited `PGOPTIONS`; preferably pin the connection address to `127.0.0.1` for every engine, including the FastAPI engine. Ensure the application's runtime engine cannot use a different address than the verified preflight.

The harness does not fall back to `forge`, `forge_workout_test`, Neon, Render, or production through its explicit `DATABASE_URL`; the concern is transport routing despite the explicit URL host.

### P2 — Application runtime search path is not pinned

Both preflight paths explicitly set `search_path=public`, but `app.core.database.engine` is created from `DATABASE_URL` without matching `connect_args`. The harness removes `PGOPTIONS` before app startup. A role-level custom search path can therefore make application requests resolve tables differently from the preflight. This is primarily a failure/misrouting risk within the approved database, but could write to a same-named table in another schema if one is earlier in the role's path.

**Recommended before execution:** make the app server's connections use the intended `public` schema and verify the same setting for the parent `SessionLocal` used by persistence assertions.

## 3. Fixture lifecycle and cleanup analysis

The fixture registers accounts through the real auth route using generated `.test` emails and random passwords, then creates unique muscle-group and exercise identities plus one active program/day and its program exercises. No existing development account or seeded exercise is selected ([registration helper](../backend/tests/test_workout_http_integration.py#L277), [workout fixture](../backend/tests/test_workout_http_integration.py#L336)).

Cleanup uses generated email/IDs and scoped ORM deletes. It deletes the fixture user's workout sessions, then program exercises, program days, training programs, and the user, followed by only the generated exercise IDs and muscle-group ID ([cleanup](../backend/tests/test_workout_http_integration.py#L439)). Workout-session foreign keys cascade to workout exercises/sets; program-exercise rows are removed before their referenced exercises, avoiding the exercise foreign key's `RESTRICT`. The secondary user is removed by its unique generated email. There is no unqualified delete, `TRUNCATE`, explicit `DROP`, or global cascade cleanup.

Fixture setup is protected by `finally` after registration; failed registration/login attempts also try to delete only the generated email ([registration helper](../backend/tests/test_workout_http_integration.py#L277)). Pytest assertion failures unwind fixtures and run teardown. The `ThreadPoolExecutor` context waits for both finish requests before the test returns and before fixture teardown begins.

### P2 — Abrupt process termination can leave test rows

The cleanup is reliable for ordinary assertion/setup exceptions, but cannot run after a hard process kill, interpreter crash, or machine shutdown. Unique generated identities prevent those rows from being mistaken for another account, but later runs do not inventory or clean them. This is a possible orphan in the dedicated test database, not a deletion risk to pre-existing records.

**Recommended:** document an operator procedure for checking generated test identities after an interrupted run. Do not add broad cleanup or automatic deletion by prefix without a separately reviewed, exact ownership guard.

## 4. Server subprocess isolation

- A real `subprocess.Popen` runs Uvicorn bound to `127.0.0.1` on a dynamically selected port; the user's server on port `8000` is neither addressed nor terminated ([server fixture](../backend/tests/test_workout_http_integration.py#L190)).
- The fixture terminates and, if necessary, kills only the process object it started ([test module](../backend/tests/test_workout_http_integration.py#L254)).
- The child receives an explicit database URL and ephemeral JWT secret, and its bootstrap checks the actual database/revision before app import. However, the child currently inherits the full parent environment before those overrides. This is the source of the libpq-variable concern above.
- Readiness uses HTTPX against loopback and checks exact health JSON and database health JSON; request polling is bounded by a 15-second deadline. HTTP requests have a 0.5-second readiness timeout ([test module](../backend/tests/test_workout_http_integration.py#L218)).

### P2 — Port reservation has a close-before-start race

The fixture binds a temporary socket to port zero, reads the selected port, closes that socket, and only then launches Uvicorn ([test module](../backend/tests/test_workout_http_integration.py#L193)). Another process can claim that port during the gap. If the child has not yet exited when readiness probes run, an unrelated service that returns the same health payload could be mistaken for the test server. This is unlikely but conflicts with the requirement that readiness cannot target an unrelated server.

**Required before execution:** remove the race by retaining/passing the bound socket to Uvicorn or by using a child-owned readiness handshake that proves the process successfully bound the selected socket before HTTP probes begin.

### P2 — Child diagnostics are suppressed

The child has `stdout` and `stderr` redirected to `DEVNULL`, while readiness failure reports only a generic message ([test module](../backend/tests/test_workout_http_integration.py#L205), [failure path](../backend/tests/test_workout_http_integration.py#L246)). This avoids accidental secret output but can make setup failures difficult to diagnose. Preserve only bounded, sanitized diagnostics if improving this behavior.

## 5. HTTP contract verification

The routes and assertions align with the inspected FastAPI definitions:

| Contract | Source and expected result | Review of test assertion |
|---|---|---|
| Register/login | Auth routes return `201` and `200` ([auth routes](../backend/app/api/v1/auth.py#L39), [schemas](../backend/app/schemas/auth.py#L7)) | Unique generated account; response keys and bearer token checked. |
| Missing/malformed auth | `get_current_user` returns `401` ([dependency](../backend/app/api/deps.py#L20)) | Both cases checked. |
| Start/current | Start returns `201`; current returns `404` when absent and `200` when active ([workout routes](../backend/app/api/v1/workouts.py#L151), [current](../backend/app/api/v1/workouts.py#L217)) | Status, session structure, exercises/sets, and current session ID checked. |
| Duplicate start / pending finish | Both are `409` ([start](../backend/app/api/v1/workouts.py#L151), [finish](../backend/app/api/v1/workouts.py#L367)) | Invalid-state statuses checked. |
| Log set / skip | Successful routes return `200`; invalid state returns `422` and missing objects return `404` ([log](../backend/app/api/v1/workouts.py#L279), [skip](../backend/app/api/v1/workouts.py#L324)) | Values and persistence checked; invalid skip/log states checked. |
| Finish/retry | Finish response model is returned with `200`; pending exercises return `409`; missing ID returns `404` ([finish](../backend/app/api/v1/workouts.py#L367)) | Completion, timestamp stability, unknown ID, and database state checked. |
| History/detail | History returns a list; owned detail returns the session; unowned/missing detail returns `404` ([history](../backend/app/api/v1/workouts.py#L246), [detail](../backend/app/api/v1/workouts.py#L411)) | Summary, detail, nested exercise statuses, and set values checked. |
| Ownership | The detail route passes `current_user` to its lookup and the start service limits program days by owner ([detail](../backend/app/api/v1/workouts.py#L411), [start lookup](../backend/app/services/workout_service.py#L85)) | A second registered user cannot start the first user's program day or view the workout. |

The program fixture creates an active program owned by the registered user, a valid program day, and two exercises whose primary muscle group exists. Each program exercise has one set with valid rep/rest bounds; it satisfies the start service's active-program and non-empty-day preconditions ([start service](../backend/app/services/workout_service.py#L85), [program/exercise models](../backend/app/models/program_exercise.py#L16)).

Decimal response assertions normalize values through `Decimal(str(...))`, avoiding an assumption that FastAPI serializes `Decimal` as either a JSON number or string. No false response-status assumptions were identified by source comparison.

## 6. Concurrent Finish reliability

Two separate synchronous HTTPX clients synchronize on a `threading.Barrier`; both issue the same Finish request. HTTPX clients have a 10-second timeout, the barrier has a 5-second timeout, and the executor context waits for both calls before continuing ([test module](../backend/tests/test_workout_http_integration.py#L648)). The route/service uses a row lock and treats an already-completed workout as idempotent ([service](../backend/app/services/workout_service.py#L489)). Both responses are expected to return `200` with the same completed timestamp; a subsequent retry and a fresh database read check timestamp stability.

This is a deterministic concurrency exercise at the client level, but it does not guarantee the server schedules both requests simultaneously. The timeout/barrier design prevents an indefinite wait under ordinary client/server failures. The port-race issue remains the more important first-run safety concern.

## 7. Dependency compatibility

The exact dependency change adds `httpx==0.28.1` to `backend/requirements-dev.txt`; existing requirements pin FastAPI `0.141.1` and pytest `9.1.1`. Installed project-virtualenv metadata reports:

- Python `3.13.15`
- FastAPI `0.141.1`
- Starlette `1.6.0`
- pytest `9.1.1`
- SQLAlchemy `2.0.52`
- psycopg `3.3.5`
- AnyIO `4.15.0`
- HTTPX and its `httpcore` dependency are not installed.

HTTPX `0.28.1` supports Python 3.13. The test uses HTTPX's outbound `Client`, not Starlette's `TestClient` or ASGI transport, so its use does not depend on Starlette's test-client integration. No package installation was performed.

**Recommendation:** for this already-aligned virtualenv, install only the declared `httpx==0.28.1` pin after review; pip will resolve HTTPX's missing transitive runtime dependencies. Reinstalling the entire development requirements file is more churn than needed here. Use the full file for a fresh or known-drifted environment.

## 8. Findings classified P0/P1/P2

| # | Severity | File | Lines | Vulnerability | Confidence |
|---|----------|------|-------|---------------|------------|
| 1 | 🟠 HIGH | `backend/tests/test_workout_http_integration.py` | 139-152, 201-213 | Inherited `PGHOSTADDR`/PostgreSQL service environment can redirect psycopg away from the validated loopback host; the child copies the environment and only clears `PGOPTIONS`. | 8/10 |
| 2 | 🟠 HIGH | `backend/tests/test_workout_http_integration.py`, `backend/requirements-dev.txt` | test:16; requirements:3 | HTTPX is imported during collection but is absent from the project virtualenv, so this module currently cannot collect/run there. | 10/10 |
| 3 | 🟡 MEDIUM | `backend/tests/test_workout_http_integration.py`; `backend/app/core/database.py` | test:35-46,139-152,177; database:7-11 | Bootstrap forces `search_path=public`, but the actual application engine does not; a role-level search path can resolve another schema or cause runtime failure. | 8/10 |
| 4 | 🟡 MEDIUM | `backend/tests/test_workout_http_integration.py` | 193-213 | Closing the temporary port socket before Uvicorn binds leaves a race; readiness could reach an unrelated same-response service before the child reports bind failure. | 8/10 |
| 5 | ⚪ LOW | `backend/tests/test_workout_http_integration.py` | 439-481 | Abrupt interpreter/host termination can bypass fixture teardown and leave uniquely generated rows in the test database. | 9/10 |
| 6 | ⚪ LOW | `backend/tests/test_workout_http_integration.py` | 205-216,246-250 | Suppressed child output and generic startup failure reduce diagnostics; no secrets are exposed, but failures may be hard to diagnose. | 9/10 |

No P0 issue was found. Findings 1 and 4 are safety-related destination risks under specific inherited-environment/race conditions; they do not establish that the current machine has those conditions.

## 9. Required fixes before first execution

1. Remove the inherited libpq redirection risk for both parent and child, preferably by using a minimal child environment and explicitly pinning the actual connection address.
2. Ensure `public` is the application's runtime search path and the parent assertion engine's search path, not only the bootstrap connection's.
3. Eliminate the port-close/start race or add a server-owned readiness handshake before HTTP probes.
4. Install HTTPX `0.28.1` in the project virtualenv. No installation occurred during this review.
5. Keep the existing unique-ID cleanup. Consider a documented operator check for leftovers after an abnormal process termination; do not add unrestricted cleanup.

## 10. Exact safe test execution procedure

Do not run until fixes 1-4 above are reviewed and applied. From Windows PowerShell, use only the backend virtualenv and the single integration module. The secure prompt avoids putting the URL in command history; the URL must still be the dedicated local integration database:

```powershell
Set-Location 'C:\Projects\forge\backend'
.\.venv\Scripts\python.exe --version

# After review, install only the missing declared client dependency.
.\.venv\Scripts\python.exe -m pip install httpx==0.28.1
if ($LASTEXITCODE -ne 0) { throw 'HTTPX installation failed.' }

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

The prompted URL must use driver `postgresql+psycopg`, host `127.0.0.1`, port `5432`, and database `forge_workout_integration_test`. Do not run combined pytest collection or use the databases `forge`, `forge_workout_test`, Neon, Render, or production. The harness must be run alone so pre-imported app modules cannot bypass its guard.

## 11. Final verdict

**NOT READY** — do not execute the integration tests yet. The explicit URL/revision guards and ID-scoped cleanup are valuable, but the inherited libpq redirection risk and port-readiness race should be closed first; HTTPX is also missing from the project virtualenv. No pytest, PostgreSQL connection, migration, server operation, mutating HTTP call, or package installation was performed during this review.
