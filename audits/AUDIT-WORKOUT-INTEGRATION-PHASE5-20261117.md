# Workout Integration Phase 5 Readiness Audit

**Scope:** Read-only inspection of Flutter, FastAPI, PostgreSQL, existing tests, and local connectivity configuration. No application/test/configuration files were changed; no tests, migrations, mutating HTTP requests, or database writes were run.

**Repository state observed:** branch `test/workout-integration-phase5`, commit `feb3222cd60c08b8d3db7437311c6a777ebbd66b` (the stated Phase 4 commit).

## 1. Repository and environment overview

- Flutter entry point: [`mobile/lib/main.dart`](../mobile/lib/main.dart#L1-L20), which starts `ForgeApp` under `ProviderScope` and routes through `AuthGate`.
- Flutter API client configuration: [`mobile/lib/core/config/api_config.dart`](../mobile/lib/core/config/api_config.dart#L1-L7); requests use the configured base URL in [`mobile/lib/core/api/api_client.dart`](../mobile/lib/core/api/api_client.dart#L85-L101).
- FastAPI entry point: [`backend/app/main.py`](../backend/app/main.py#L18-L70), mounting application routers under `/api/v1`.
- Workout HTTP handlers, service, schemas, models, and migrations were inspected in `backend/app/api/v1/workouts.py`, `backend/app/services/workout_service.py`, `backend/app/schemas/workout.py`, `backend/app/models/`, and `backend/alembic/`.
- Database settings read `DATABASE_URL` through `Settings` and `.env` loading in [`backend/app/core/config.py`](../backend/app/core/config.py#L4-L15); Alembic uses the same setting in [`backend/alembic/env.py`](../backend/alembic/env.py#L12-L18).
- Docker container `forge_postgres` is running. The read-only Docker port query returned `0.0.0.0:5432` and `[::]:5432`. The Compose mapping is unqualified `5432:5432` in [`docker-compose.yml`](../docker-compose.yml#L4-L13).
- The Windows environment has `backend/.venv` available per task context. No `.env` or other secret-bearing file was opened, and no environment variable values or connection strings were read or reported.

## 2. Architecture and data flow

`AuthGate` restores a stored session, calls the authenticated user endpoint, then routes into the authenticated app. `ApiClient` adds `Authorization: Bearer ...`, refreshes on a 401 through `/auth/refresh`, shares an in-flight refresh, and retries the failed request once ([`api_client.dart`](../mobile/lib/core/api/api_client.dart#L25-L82), [`api_client.dart`](../mobile/lib/core/api/api_client.dart#L105-L220)).

The program screen loads the user's active program through `ProgramRepository`; `ProgramDetailScreen` passes a selected `program_day_id` to `WorkoutController.startWorkout`. The session screen calls the controller for set logging, exercise skipping, and Finish. History/detail screens use the same workout provider/repository for refreshes and detail reads.

FastAPI mounts `/auth`, `/users`, `/programs`, and `/workouts` under `/api/v1`. Program/workout routes that access user data depend on `get_current_user`; it validates an active user from the JWT subject ([`backend/app/api/deps.py`](../backend/app/api/deps.py#L15-L56)). Workout writes commit in the service. Set, skip, and Finish operations lock relevant rows with `FOR UPDATE`; Finish returns the existing completed row for an idempotent same-ID retry ([`workout_service.py`](../backend/app/services/workout_service.py#L324-L359), [`workout_service.py`](../backend/app/services/workout_service.py#L489-L541)). A partial unique index enforces one in-progress session per user ([`workout_session.py`](../backend/app/models/workout_session.py#L21-L49)).

## 3. Flutter–FastAPI endpoint mapping

Paths in the table are relative to the Flutter base URL; the full HTTP path is `/api/v1` plus the listed path. FastAPI mounts the routers under that prefix.

| Lifecycle step | Flutter caller / request | Backend contract and persistence |
|---|---|---|
| Login | `AuthRepository.login`: `POST /auth/login`, JSON `{email, password}`; then `GET /users/me` | Login returns 200 with `access_token`, `refresh_token`, `token_type`; `/users/me` returns 200 `UserResponse`. The mobile client stores tokens and loads the user ([`auth_repository.dart`](../mobile/lib/features/auth/data/auth_repository.dart#L33-L85), [`auth.py`](../backend/app/api/v1/auth.py#L62-L96), [`users.py`](../backend/app/api/v1/users.py#L16-L25)). |
| Refresh auth | Dio interceptor: `POST /auth/refresh`, JSON `{refresh_token}` | 200 with rotated access/refresh tokens; invalid/expired refresh token returns 401. The endpoint checks that the referenced user still exists and is active ([`api_client.dart`](../mobile/lib/core/api/api_client.dart#L105-L174), [`auth.py`](../backend/app/api/v1/auth.py#L98-L148)). |
| Load active program | `ProgramRepository.getCurrentProgram`: `GET /programs/current` | 200 `ProgramDetailResponse`; 404 when no active program. The repository maps 404 to `null` ([`program_repository.dart`](../mobile/lib/features/program/data/program_repository.dart#L18-L31), [`programs.py`](../backend/app/api/v1/programs.py#L274-L304)). Program generation is a separate `POST /programs/generate`, 201, with no request body; it requires the user's setup and exercise data ([`programs.py`](../backend/app/api/v1/programs.py#L164-L205)). |
| Start workout | Program day Start button → controller → `POST /workouts/start`, JSON `{program_day_id}` | 201 `WorkoutSessionResponse`; validates that the day belongs to the user's active program and is non-empty. An already-active workout maps to 409; missing day to 404; empty day to 422. Service creates a session plus exercise/set snapshots ([`program_detail_screen.dart`](../mobile/lib/features/program/presentation/program_detail_screen.dart#L44-L60), [`workout_repository.dart`](../mobile/lib/features/workout/data/workout_repository.dart#L53-L64), [`workouts.py`](../backend/app/api/v1/workouts.py#L146-L209), [`workout_service.py`](../backend/app/services/workout_service.py#L132-L264)). |
| Get current workout | Controller build/refresh: `GET /workouts/current` | 200 session or 404 when none is in progress. Flutter maps 404 to `null` ([`workout_repository.dart`](../mobile/lib/features/workout/data/workout_repository.dart#L39-L51), [`workouts.py`](../backend/app/api/v1/workouts.py#L213-L237)). |
| Log set | Session sheet → `PATCH /workouts/sets/{workout_set_id}`, JSON `{actual_reps, weight_kg, rpe}` | 200 `WorkoutSetResponse`; `actual_reps >= 0`, optional nonnegative `weight_kg`, optional `rpe` from 1–10. Missing set maps to 404; invalid state/value to 422. Service commits the set transition ([`workout_session_screen.dart`](../mobile/lib/features/workout/presentation/workout_session_screen.dart#L175-L248), [`workout_repository.dart`](../mobile/lib/features/workout/data/workout_repository.dart#L66-L82), [`workout.py`](../backend/app/schemas/workout.py#L12-L38), [`workouts.py`](../backend/app/api/v1/workouts.py#L275-L316)). |
| Skip exercise | Session screen → `POST /workouts/exercises/{workout_exercise_id}/skip`, no body | 200 `WorkoutExerciseResponse`; missing exercise maps to 404, invalid/completed state to 422. Service commits the skipped status ([`workout_session_screen.dart`](../mobile/lib/features/workout/presentation/workout_session_screen.dart#L264-L306), [`workout_repository.dart`](../mobile/lib/features/workout/data/workout_repository.dart#L84-L95), [`workouts.py`](../backend/app/api/v1/workouts.py#L320-L359), [`workout_service.py`](../backend/app/services/workout_service.py#L361-L409)). |
| Finish workout | Session screen → `POST /workouts/{workout_id}/finish`, no body | 200 `WorkoutSessionResponse`; pending exercises return 409, invalid session state 422, missing/unauthorized session 404. Same-ID retry after completion returns the same completed session without changing `completed_at` ([`workout_session_screen.dart`](../mobile/lib/features/workout/presentation/workout_session_screen.dart#L311-L360), [`workout_repository.dart`](../mobile/lib/features/workout/data/workout_repository.dart#L97-L107), [`workouts.py`](../backend/app/api/v1/workouts.py#L363-L403), [`workout_service.py`](../backend/app/services/workout_service.py#L489-L541)). |
| Fetch history | Controller initial build/refresh and history screen: `GET /workouts/history` | 200 list of `WorkoutSummaryResponse`; service selects the user's sessions ordered by start time ([`workout_repository.dart`](../mobile/lib/features/workout/data/workout_repository.dart#L121-L137), [`workouts.py`](../backend/app/api/v1/workouts.py#L240-L272), [`workout_service.py`](../backend/app/services/workout_service.py#L471-L486)). |
| Completed detail | History detail provider: `GET /workouts/{workout_id}` | 200 `WorkoutSessionResponse`, or 404 for missing/not-owned workout ([`workout_controller.dart`](../mobile/lib/features/workout/presentation/workout_controller.dart#L450-L457), [`workout_repository.dart`](../mobile/lib/features/workout/data/workout_repository.dart#L109-L119), [`workouts.py`](../backend/app/api/v1/workouts.py#L407-L432)). |
| Refresh/reload | History pull-to-refresh, detail warning action, session retry: controller refreshes current and/or history | `GET /workouts/current` and `GET /workouts/history`; no Finish request is sent. The history-detail screen exposes `REFRESH HISTORY` without invoking Finish ([`workout_history_screen.dart`](../mobile/lib/features/workout/presentation/workout_history_screen.dart#L15-L40), [`workout_history_detail_screen.dart`](../mobile/lib/features/workout/presentation/workout_history_detail_screen.dart#L20-L52), [`workout_controller.dart`](../mobile/lib/features/workout/presentation/workout_controller.dart#L233-L303)). |

### Contract mismatch found

The backend's `WorkoutExerciseResponse` and database exercise/session snapshot do not define or return `is_bodyweight` ([`workout.py`](../backend/app/schemas/workout.py#L41-L62), [`workout_exercise.py`](../backend/app/models/workout_exercise.py#L1-L80)). The Flutter parser treats that field as optional and defaults it to `false` ([`workout_models.dart`](../mobile/lib/features/workout/data/workout_models.dart#L105-L117)); the session UI uses it to hide the weight input ([`workout_session_screen.dart`](../mobile/lib/features/workout/presentation/workout_session_screen.dart#L1670-L1690)). Therefore live responses currently make this UI behave as if every exercise is weighted. This does not break JSON parsing, but the bodyweight-specific UI contract is not fulfilled.

## 4. Authentication contract

- `POST /api/v1/auth/register` accepts `full_name`, `email`, and `password`, returns 201 `UserResponse`; the mobile registration path then performs login.
- `POST /api/v1/auth/login` accepts `email` and `password`, returns 200 `{access_token, refresh_token, token_type}`.
- `GET /api/v1/users/me` requires a Bearer access token and returns `id`, `email`, `full_name`, `role`, `is_active`, and `created_at`; these fields match `AuthUser`.
- `POST /api/v1/auth/refresh` accepts `refresh_token` and returns a replacement token pair. The API client refreshes once per concurrent 401 set, retries a request once, and distinguishes invalid sessions from temporary refresh failures.
- Workout and program requests require an active authenticated user. Auth registration/login/refresh are unauthenticated endpoints.

Schema and caller references: [`auth.py`](../backend/app/schemas/auth.py#L7-L83), [`auth.py`](../backend/app/api/v1/auth.py#L34-L148), [`deps.py`](../backend/app/api/deps.py#L15-L56), [`auth_repository.dart`](../mobile/lib/features/auth/data/auth_repository.dart#L33-L85), [`auth_user.dart`](../mobile/lib/features/auth/data/auth_user.dart#L1-L28).

## 5. Database safety

### What was verified read-only

Using the local `forge` role, read-only catalog queries found databases `forge`, `forge_workout_test`, and `postgres`. The `forge_workout_test` database is owned by role `forge`, accepts connections, contains the application tables in `public`, and reports Alembic revision `a4f6c91d2e7b`. No application rows were queried. No DDL, DML, reset, migration, or database creation was performed.

### Existing test isolation

`backend/tests/test_workout_lifecycle.py` has:

- A default SQLite in-memory fixture for service tests.
- A PostgreSQL fixture that skips unless `WORKOUT_TEST_DATABASE_URL` is set; it rejects non-PostgreSQL URLs and database names not ending `_test`.
- A per-run randomly named schema created for tests and dropped with `CASCADE` in fixture cleanup; the fixture verifies `current_database()` equals the database name in the supplied URL ([`test_workout_lifecycle.py`](../backend/tests/test_workout_lifecycle.py#L57-L130)).

This is materially safer than dropping/recreating the database, and `forge_workout_test` matches the suffix guard. However, the guard does not validate server host, network identity, or an allowlist; a remote database named `*_test` would also pass. The FastAPI engine and Alembic target instead use `DATABASE_URL` from the process environment or backend `.env`, with no test-only target guard. A server or `alembic upgrade` started without an explicitly verified `DATABASE_URL` could therefore target a different database. The live server must not inherit an unreviewed development/production target.

The test database currently already has a public schema and application tables. Do not use that schema for integration data. Recommended:

1. Prefer an explicitly approved local disposable database, e.g. the existing `forge_workout_test` only after its owner confirms it is disposable and not shared with other work.
2. Use a uniquely named per-run schema with `search_path` for both the app and migration process; preserve `public` and the `forge` database.
3. If the existing test database cannot be confirmed isolated, request approval to create a dedicated local `forge_workout_integration_test`; do not repurpose `forge`.
4. Verify database name, user, server/port, and schema in a read-only preflight before any migration or test that writes. Set both `DATABASE_URL` and `WORKOUT_TEST_DATABASE_URL` explicitly in the process running the test/server.
5. Apply Alembic only to the verified isolated target. The current public-schema Alembic revision is evidence about that schema only, not about any future per-run schema.

### Network exposure

The running PostgreSQL container publishes port 5432 on `0.0.0.0` and `::`. This confirms binding on all host interfaces; it does **not** prove that the database is reachable from the public Internet because Windows firewall/router policy was not inspected. Before device testing, verify firewall reachability and restrict the database to loopback/private trusted interfaces. Do not expose PostgreSQL or FastAPI publicly.

## 6. Flutter API connectivity configuration

`API_BASE_URL` is a compile-time Dart define. Its default is `http://127.0.0.1:8000/api/v1` ([`api_config.dart`](../mobile/lib/core/config/api_config.dart#L1-L7)). There is no platform-specific URL selection. The Dio client uses 15-second connect and 30-second send/receive timeouts ([`api_client.dart`](../mobile/lib/core/api/api_client.dart#L95-L101)).

| Target | Base URL to use | Notes |
|---|---|---|
| Windows local app | `http://127.0.0.1:8000/api/v1` | Default is suitable if FastAPI is running on the same host and bound to loopback. |
| Android emulator | `http://10.0.2.2:8000/api/v1` | `127.0.0.1` refers to the emulator itself. Also verify the app's Android cleartext policy before using HTTP. |
| iOS simulator | `http://127.0.0.1:8000/api/v1` when the server is on the Mac | This checkout is on Windows; iOS simulator execution requires macOS/Xcode and was not validated here. |
| Physical Android | `http://<host-private-LAN-IP>:8000/api/v1` for isolated development, preferably HTTPS | Device and host must be on a trusted network; backend must listen on a reachable private interface and firewall must allow only the test device/network. |
| Physical iPhone | `http://<host-private-LAN-IP>:8000/api/v1` for isolated development, preferably HTTPS | Requires macOS/Xcode to build/run. Test the iOS App Transport Security behavior; no ATS exception is present in `Info.plist`. |

Android's `INTERNET` permission appears in the debug and profile manifests but not the main manifest ([`debug/AndroidManifest.xml`](../mobile/android/app/src/debug/AndroidManifest.xml#L1-L7), [`profile/AndroidManifest.xml`](../mobile/android/app/src/profile/AndroidManifest.xml#L1-L7), [`main/AndroidManifest.xml`](../mobile/android/app/src/main/AndroidManifest.xml#L1-L45)). The Gradle target SDK follows `flutter.targetSdkVersion` ([`build.gradle.kts`](../mobile/android/app/build.gradle.kts#L8-L24)). No `usesCleartextTraffic` or network security configuration was found, and `Info.plist` has no `NSAppTransportSecurity` declaration. Consequently, do not assume the default HTTP URL works on Android/iOS; validate the actual target policy or use development HTTPS/scoped debug-only exceptions. Do not add a blanket cleartext exception.

Safe override examples (not executed):

```powershell
flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
flutter run -d <android-emulator-id> --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

For physical devices, substitute a private LAN address only after restricting backend binding/firewall access. Never bind a development server to all public interfaces.

## 7. Existing integration-test coverage

- Backend has four test modules. `test_workout_lifecycle.py` tests the service/database paths, including PostgreSQL concurrency, but no `TestClient`, HTTPX client, or FastAPI dependency override is present in the test suite. Its PostgreSQL concurrency tests use schema isolation and can be skipped when the explicit test URL is unset. `httpx` is already declared in backend requirements.
- Flutter has three test files: workout Finish/recovery tests, API auth-client regression tests, and a widget smoke test. Workout tests use a fake Dio adapter; no `mobile/integration_test` directory or `integration_test` dependency is present in `pubspec.yaml`.
- The prior reported backend `52 passed` and Flutter `28 passed` are historical unit/service/widget validation, not live FastAPI/PostgreSQL or Flutter-to-server results. They were not rerun for this audit.
- No HTTP request, Flutter test, backend test, migration, or mutating database operation was executed during this audit.

## 8. Findings by severity

### P0 — Critical

None identified by this read-only audit.

### P1 — Blocking integration / operational gates

1. **Android release manifest lacks network permission (confirmed configuration defect).** `INTERNET` is declared only in debug/profile manifests, not `src/main/AndroidManifest.xml`. A release build can therefore lack network access to the API. This does not necessarily block a debug-only emulator test, but it blocks production/release end-to-end readiness. Add/verify the permission in the main manifest before release validation.
2. **Do not run mutating PostgreSQL tests or Alembic until the target is explicitly verified.** The current Postgres test fixture creates and drops schemas in any supplied PostgreSQL database whose name ends `_test`; it does not validate the host. FastAPI/Alembic independently use `DATABASE_URL` and have no isolated-test guard. This is a concrete execution safety gate, not evidence that the current environment has written to the wrong database. Use the read-only preflight and explicitly set both variables to the approved local disposable target.
3. **All-interface PostgreSQL bind must be reviewed before device/network tests.** Docker reports `0.0.0.0:5432` and `[::]:5432`. Firewall/public reachability is unverified, so external exposure is not claimed; verify/restrict it before any test over a non-loopback network.

### P2 — Non-blocking defects / coverage gaps

1. **Bodyweight exercise contract is incomplete.** Backend response/model has no `is_bodyweight`; Flutter defaults it to false, while the session UI uses it to decide whether to show weight entry. Add a contract-level test and decide how that attribute should be supplied before treating bodyweight exercise flows as covered.
2. **No live HTTP integration coverage exists.** Current backend tests exercise services and database behavior, and mobile API tests use fakes. This is an evidence gap, not a claim that the endpoints fail.
3. **HTTP platform policy is not established.** The base URL is HTTP; Android target SDK is delegated to the installed Flutter SDK and no explicit cleartext policy was found; iOS ATS exceptions are absent. Verify real target behavior or use development HTTPS with narrowly scoped exceptions.
4. **The database port binding has unverified reachability.** The all-interface bind is confirmed, but host firewall/router behavior was not tested. Treat it as a precondition for safe device access, not as confirmed Internet exposure.

## 9. Recommended isolated database setup

The existing `forge_workout_test` is the strongest candidate observed: it exists, is owned by the local `forge` role, has application tables, and is at revision `a4f6c91d2e7b`. Its name satisfies the existing `_test` guard. The audit cannot establish whether it is disposable, idle, or shared; obtain that confirmation before writing.

Preferred execution isolation is a unique schema per run on this database, or a separately approved `forge_workout_integration_test` database if the existing test DB is shared. Never target `forge`, Neon, Render, or production. Use a dedicated test user with least privilege where the local setup permits. Keep the API bound to loopback for local HTTP tests; a physical-device test must use a private network and firewall allowlist.

The FastAPI application exposes `/api/v1/health` and `/api/v1/health/database`; these are useful after starting the server. The database health endpoint executes only `SELECT 1` ([`main.py`](../backend/app/main.py#L80-L101)).

## 10. Phase 5 execution plan and acceptance criteria

| Phase | Work | Acceptance and safety checks |
|---|---|---|
| **5A — Readiness audit** | Complete this architecture, contract, and safety review. | Paths/endpoints are verified from source; no test writes are performed; risks and prerequisites are recorded. **Complete.** |
| **5B — Disposable PostgreSQL preparation** | Owner confirms `forge_workout_test` is disposable/idle or approves a dedicated `*_test` DB. Choose a per-run schema, verify host/database/user with read-only queries, then apply migrations only to the isolated target. | The target is local and explicitly disposable; `current_database()`/`current_user` match the approved target; `forge` and production remain untouched; migration revision is verified; cleanup drops only the unique test schema. |
| **5C — Real FastAPI HTTP tests** | Start Uvicorn on loopback with explicit test `DATABASE_URL`; use existing HTTPX to exercise login, auth, program fixture, and workout lifecycle via actual HTTP. | Real status/body contracts match Flutter models; DB asserts confirm start/log/skip/finish/history; repeated and concurrent Finish return the same completed session; tests cannot use non-`*_test` DBs. HTTP failure injection is test-only and does not change production code. |
| **5D — Flutter-to-backend tests** | Run Flutter against that server with `--dart-define=API_BASE_URL=...`; use a unique test account and deterministic active-program/day/exercise fixture. | Real Dio requests work with bearer/refresh flow; start/current/set/skip/finish/history/detail and refresh are verified; no fake adapter is used for the integration case. Add Flutter SDK integration-test tooling only if automated device execution is required. |
| **5E — Network and lifecycle recovery** | Inject an ambiguous Finish response after server commit, fail a later history GET, then recreate the provider/restart the app. Use a controlled local proxy or test-only server fault hook. | One same-ID reconciliation confirms completion; no second Start/Finish is sent automatically; history failure does not undo completion; refresh history does not call Finish; authoritative current/history is restored after recreation. |
| **5F — Final validation and review** | Run focused backend HTTP tests, relevant Flutter tests, platform smoke tests, analyzer/format, and review DB cleanup. | Record actual results separately for backend HTTP, Flutter client, emulator, and physical-device tests; verify no test schema remains and the development/production databases are unchanged. |

### Required scenarios and appropriate layer

- **Backend HTTP:** A authentication/authorization; B Start persistence; C set persistence; D skip persistence; E Finish status/time; F idempotent retry; G history; H current after completion; I concurrent Finish.
- **Flutter-to-backend / controlled fault injection:** J history GET failure after confirmed Finish; K dropped Finish response followed by same-ID detail reconciliation; L provider recreation/app restart reloads server state.
- **Emulator/device:** verify actual base URL, Android cleartext/permission behavior, iOS ATS, token storage, and network loss/reconnect. These are not established by service tests or fake-Dio tests.
- Use a unique per-run test identity and deterministic user/program/day/exercise fixture. Existing service helper `_create_program` is useful as a pattern; no account or fixture data was created during this audit.

## 11. Exact next commands (future execution only)

Do not run the migration/test commands until a human confirms that the selected database is disposable and the host/firewall are restricted. The URL placeholders below are intentionally non-secret placeholders; do not paste actual credentials into this report or command output.

Read-only local preflight:

```powershell
docker port forge_postgres 5432
docker exec forge_postgres psql --username forge --dbname forge_workout_test --no-psqlrc --tuples-only --no-align --command "SELECT current_database(), current_user;"
docker exec forge_postgres psql --username forge --dbname forge_workout_test --no-psqlrc --tuples-only --no-align --command "SELECT version_num FROM alembic_version;"
```

After confirming the test DB and setting the two environment variables privately to the same approved local `*_test` target (including the selected schema/search path where applicable):

```powershell
$env:DATABASE_URL = '<approved-local-disposable-test-database-url>'
$env:WORKOUT_TEST_DATABASE_URL = '<same-approved-local-disposable-test-database-url>'
Set-Location C:\Projects\forge\backend
.\.venv\Scripts\python.exe -m alembic current
# Only after verifying the output points to the approved test target:
.\.venv\Scripts\python.exe -m alembic upgrade head
.\.venv\Scripts\python.exe -m pytest -q tests/test_workout_lifecycle.py
```

For an HTTP test server, keep it loopback-bound and pass the same explicit test `DATABASE_URL`:

```powershell
Set-Location C:\Projects\forge\backend
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Then verify only the read-only health endpoints and run the mobile app with a target-appropriate URL:

```powershell
curl.exe --fail http://127.0.0.1:8000/api/v1/health
curl.exe --fail http://127.0.0.1:8000/api/v1/health/database
Set-Location C:\Projects\forge\mobile
flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

For Android emulator, replace the define with `http://10.0.2.2:8000/api/v1` and first resolve/verify the Android HTTP transport policy. Do not use a public address or bind the test server to all interfaces.

## 12. Final readiness assessment

**Phase 5 integration testing has not been performed.** The code paths and contracts are sufficiently mapped to begin backend integration-test preparation, but no HTTP or mobile-to-server result can be claimed.

**Overall: NOT READY for unrestricted end-to-end/device testing.** First confirm and explicitly select the disposable database, restrict/verify PostgreSQL network access, and resolve the Android release permission. For local backend-only testing, proceed only after the Phase 5B database safety checks. Windows local Flutter connectivity can be attempted with the `API_BASE_URL` override; Android emulator cleartext behavior and iOS networking remain unverified.

**Exact file recommended for staging:** `audits/AUDIT-WORKOUT-INTEGRATION-PHASE5-20261117.md` only. No source, test, database, or configuration file was changed.
