# FORGE — Workout Lifecycle Phase 2 Test Review

**Last updated:** 11 November 2026  
**Branch:** `test/workout-lifecycle-phase2`  
**HEAD at initial inspection:** `e9b974e576c3abb9a71fcdf93ab961bb1c90cc67`  
**Scope:** PostgreSQL concurrency regression tests for Log Set, Skip Exercise, and Finish Workout; test synchronization, contention evidence, negative controls, and commit readiness.

## 1. Original HIGH Finding

The original review found that final-set Log/Log and Log/Skip tests synchronized at a barrier before their locking lookups. This guaranteed overlap at a Python call boundary but did not prove PostgreSQL lock contention. The tests could pass under serialized execution even if the row lock were removed. The finding concerned test quality, not proof that production locking was broken.

- Final-set Log/Log: [test_workout_lifecycle.py](../backend/tests/test_workout_lifecycle.py#L706).
- Log/Skip: [test_workout_lifecycle.py](../backend/tests/test_workout_lifecycle.py#L809).

## 2. Previous Test Strengthening

The tests were changed to hold the first request after its `WorkoutExercise` lookup returns and make the second request approach the same exercise row. An observer checks PostgreSQL `pg_blocking_pids()`; final database-state assertions and two test-only no-lock negative controls were added. Finish retry test was renamed to describe the actual 422 response.

The user-reported PostgreSQL run for that version was **16 collected, 14 passed, 2 failed, 0 skipped**. Both primary contention tests failed with `TimeoutError` inside the first worker's wait for `release_first`. Both negative controls passed. These were the results before the harness repair described below.

## 3. Timeout Root Cause

The prior runner placed its coordination waits inside `with ThreadPoolExecutor(...)` but set `release_first` in an outer `finally`. On a coordination timeout, control first exited the executor context, whose `shutdown(wait=True)` waited for the first worker. That worker was itself blocked on `release_first`, so its own 15-second timeout raised before the outer `finally` could release it.

After executor shutdown, the helper retrieved `first_future.result()` before `second_future.result()`. Thus the first worker's timeout could mask an exception from the second worker or the original coordination failure. The reported timeout therefore identifies a cleanup/diagnostics bug in the test harness; it does not explain why the second request failed to signal, and it does not establish a production locking defect.

## 4. Evidence and Diagnostics

- `first_lock_acquired` is signaled only after the first service lookup returns. With the existing `SELECT ... FOR UPDATE`, its SQLAlchemy transaction remains open while the worker waits; the service commits only after the test releases that worker. The row lock should remain held during observation, unless an exception or transaction end occurs.
- `second_lock_attempting` is signaled immediately before the second service lookup. It proves arrival at the monkeypatched lookup boundary, not by itself that the SQL statement was sent.
- Each worker obtains `pg_backend_pid()` through its own SQLAlchemy session before the operation. The same session transaction retains its database connection for subsequent ORM work. The configured pool allows four connections, enough for two workers and the observer.
- PostgreSQL `pg_blocking_pids(blocked_pid)` is an appropriate row-lock contention check. The previous helper reduced the result to a boolean and did not retain activity/wait diagnostics.
- The previous run did not include worker exception details or a `pg_stat_activity` snapshot. The underlying reason the second worker failed to signal remains unverified from that run.
- The existing locking queries are in the pre-existing worktree change at [workout_service.py](../backend/app/services/workout_service.py#L275) and [line 508](../backend/app/services/workout_service.py#L508). They were not changed during this task.

## 5. Harness Changes

The runner at [test_workout_lifecycle.py](../backend/tests/test_workout_lifecycle.py#L328) now:

- Captures a coordination exception and signals `release_first` in `finally` **before** waiting for executor shutdown.
- Waits on worker progress while checking whether the associated future failed or completed early, surfacing its result/exception rather than blindly waiting the full timeout.
- Collects results from both futures after releasing the first worker; failures include both worker tracebacks and completed outcomes, avoiding first-future masking.
- Confirms distinct worker backend PIDs before observing contention.
- Uses the observer's independent engine connection to query `pg_stat_activity`, including `state`, `wait_event_type`, `wait_event`, and `pg_blocking_pids(pid)`. Failed observations now include the last activity snapshot.

The first worker waits only for the runner's release event; its competing 15-second timeout was removed. The runner's bounded waits and `finally` cleanup avoid a worker/observer/release deadlock. The two primary tests retain HTTP and final database-state assertions. The no-lock negative controls remain present.

## 6. PostgreSQL Validation Results

**Latest user-run PostgreSQL validation of the repaired harness:**

- Workout lifecycle tests: **16 passed, 0 failed, 0 skipped**, 2 `StarletteDeprecationWarning`; runtime **5.25 seconds**.
- Full backend regression: **46 passed, 0 failed, 0 skipped**, 2 `StarletteDeprecationWarning`; runtime **4.55 seconds**.
- Scenarios validated: concurrent Log/Log, Log/Skip, Log/Finish, Skip/Finish, concurrent Start, and both no-lock negative controls.
- The previous harness timeout did **not** recur in this latest run. Both primary contention tests and negative controls passed with the harness repair.

These results were supplied by the user and were not independently rerun in this environment. Local validation below remains distinct.

Earlier historical results:

- Immediately previous harness: 16 collected, 14 passed, 2 failed, 0 skipped; the two contention tests timed out and both negative controls passed.
- Before explicit contention checks: PostgreSQL concurrency 5 passed and full backend regression 44 passed.

## 7. Current Validation

Local checks in this environment (separate from the latest user-run PostgreSQL validation):

- `python -m pytest backend\tests\test_workout_lifecycle.py -q`: **collection failed** with `ModuleNotFoundError: No module named 'sqlalchemy'`.
- `WORKOUT_TEST_DATABASE_URL`: **not set**, so PostgreSQL tests could not run.
- Python AST parse for `backend/tests/test_workout_lifecycle.py`: **passed**.
- `git diff --check`: **passed**.
- A prior attempt to install `backend/requirements-dev.txt` dependencies could not resolve pinned `alembic==1.19.2` from the configured package index. No dependency manifest was changed.

## 8. Negative-Control Results

Both test-only negative controls remain unchanged and passed in the latest user-run PostgreSQL validation:

- Final-set no-lock race: [test_workout_lifecycle.py](../backend/tests/test_workout_lifecycle.py#L1018).
- Log/Skip no-lock race: [test_workout_lifecycle.py](../backend/tests/test_workout_lifecycle.py#L1097).

Their successful results show the controls still reproduce the expected race outcomes with locking disabled. The prior 14-pass/2-fail results were from before the harness repair; the latest run reports both controls and both primary locking tests passed.

## 9. Remaining Risks

- The specific second-worker failure from the earlier 14-pass/2-fail run remains unidentifiable without its traceback and activity snapshot. The latest run establishes that the repaired tests no longer time out, but does not retroactively diagnose that earlier event.
- Latest successful user-run tests cover the listed scenarios, not every possible concurrency interleaving, database failure, or request retry pattern.
- Other Log/Finish and Skip/Finish synchronization still identifies a pending-exercise count by matching rendered SQL text, which could cause a false failure if SQL rendering changes.
- Finish retry remains non-idempotent (HTTP 422 after a successful finish); that behavior is outside this task.
- PostgreSQL fixture isolation still requires a database name ending in `_test` and creates a temporary schema.

## 10. Modified Files and Final Commit Readiness

This task changed only:

- [test_workout_lifecycle.py](../backend/tests/test_workout_lifecycle.py): event/future handling, release ordering, worker error diagnostics, and observer diagnostics.
- This report.

`backend/app/services/workout_service.py` was already modified in the worktree and was not edited in this task. No database or migration was touched; untracked files were preserved.

**Final decision: ready to commit with scoped coverage.** The latest user-run PostgreSQL validation reports all 16 lifecycle tests and all 46 backend tests passing, including both primary contention tests and both negative controls; the prior harness timeout did not recur. This supports the locking behavior and test harness for the enumerated scenarios, but does not prove all possible concurrency combinations are safe. Finish Workout retry remains non-idempotent and returns HTTP 422 after a successful finish; it is a separate known issue and was not fixed here. Local rerun was unavailable because SQLAlchemy and `WORKOUT_TEST_DATABASE_URL` are absent in this environment.
