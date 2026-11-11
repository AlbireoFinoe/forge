# FORGE — Workout Lifecycle Phase 3 Final Code Review

**Date:** 11 November 2026
**Branch:** `test/workout-finish-idempotency`
**Comparison base:** `bbd45b59fec2c19a367dacf76fbd5ed1d7d612d4` (`bbd45b5`)
**Review type:** Read-only production-code and test review. No source, test, Flutter, migration, or database files were changed. No secrets were read.

## Reviewed files and changes

The implementation diff against `bbd45b5` contains two code files:

- [workout_service.py](../backend/app/services/workout_service.py): adds the owner-scoped session and exercise lock helpers; makes Skip and Log Set acquire locks in parent-then-child order; locks Finish before checking status; returns the stored completed session on retry; refreshes Set data before mutation.
- [test_workout_lifecycle.py](../backend/tests/test_workout_lifecycle.py): adds retry, rejection, ownership, Finish concurrency and ordering coverage; updates race coordination and keeps Phase 1/2 tests and negative controls.

The requested validation and fix reports were also updated. No other code-file changes were included in the diff against the named base.

## Confirmed strengths

- **Finish locks before checking status.** `finish_workout` calls `_lock_workout_session_for_user` before examining session status. The helper filters by both session ID and owner, uses `populate_existing=True`, and applies `FOR UPDATE`: [workout_service.py](../backend/app/services/workout_service.py#L324), [workout_service.py](../backend/app/services/workout_service.py#L489).
- **Completed retry does not update the completion timestamp.** The completed branch commits and refreshes the existing session, then returns before the assignment to `completed_at`: [workout_service.py](../backend/app/services/workout_service.py#L503). The sequential and lost-response tests assert the returned and persisted timestamp is unchanged: [test_workout_lifecycle.py](../backend/tests/test_workout_lifecycle.py#L940), [test_workout_lifecycle.py](../backend/tests/test_workout_lifecycle.py#L986).
- **Finish/Finish production serialization is sound.** Both transactions lock the same owned parent row before checking status. The second waiter observes the committed `completed` state after acquiring the lock and takes the no-update retry path.
- **Log Set and Skip use a consistent lock order.** Both perform an owner-filtered ID discovery without taking child locks, lock and refresh the parent session, validate its status, and then lock and refresh the exercise: [workout_service.py](../backend/app/services/workout_service.py#L275), [workout_service.py](../backend/app/services/workout_service.py#L342), [workout_service.py](../backend/app/services/workout_service.py#L549). Log Set refreshes the set before changing it: [workout_service.py](../backend/app/services/workout_service.py#L589).
- **Ownership is enforced on the reviewed mutation paths.** Finish uses the owned-session helper. Log Set and Skip discover through a join filtered by `WorkoutSession.user_id`, then re-check ownership when acquiring the session lock. A lost/deleted or no-longer-owned row is treated as not found.
- **Identity-map freshness is addressed.** The parent and exercise locking queries use `populate_existing=True`; the Set query does as well. This prevents a previously loaded ORM object in the same SQLAlchemy session from supplying stale status or set values after lock acquisition: [workout_service.py](../backend/app/services/workout_service.py#L324), [workout_service.py](../backend/app/services/workout_service.py#L342), [workout_service.py](../backend/app/services/workout_service.py#L589).
- **No lock-order deadlock was identified among these paths.** Finish locks only the parent before its pending-exercise read. Log Set and Skip do not lock an exercise before waiting for the parent. They all acquire parent before child, with no new reverse-order or multi-parent acquisition.
- **Rejected mutations roll back.** Skip, Finish, and Log Set each wrap the transaction in `try/except`, call `db.rollback()` on exceptions, and re-raise: [workout_service.py](../backend/app/services/workout_service.py#L361), [workout_service.py](../backend/app/services/workout_service.py#L489), [workout_service.py](../backend/app/services/workout_service.py#L647). Successful request sessions are closed by the existing `get_db` dependency: [database.py](../backend/app/core/database.py#L24).
- **Start Workout is unaffected by the implementation diff.** Its service and endpoint behavior were not modified. The shared `SessionLocal` remains request-scoped; no new persistent transaction or session is introduced.

## Findings

### P0

None.

### P1

None.

### P2

1. **Finish/Finish test does not deterministically prove the lock was acquired by one request before the other checks status.** The start barrier in `test_concurrent_finish_requests_are_idempotent` synchronizes entry to the service, but does not wait until both requests have reached a particular database state or observe one PID blocked by the other. The test compares response timestamps, but it does not assert that `SteppedClock.now()` was called exactly once: [test_workout_lifecycle.py](../backend/tests/test_workout_lifecycle.py#L1144). A scheduling-dependent run could serialize even without the intended lock, and post-commit refreshes can make responses reflect the same final row. The service implementation is correct by inspection, and the separate Finish/Log and Finish/Skip tests do observe PostgreSQL blocking; this is a test-strength limitation, not a production correctness defect. A follow-up should directly observe Finish/Finish lock contention or assert a single transition under a deterministic overlap.

2. **No negative-owner tests were found for Log Set or Skip.** The implementation does apply ownership filters and rechecks ownership at the parent lock, but the explicit ownership regression test covers Finish only: [workout_service.py](../backend/app/services/workout_service.py#L275), [workout_service.py](../backend/app/services/workout_service.py#L549), [test_workout_lifecycle.py](../backend/tests/test_workout_lifecycle.py#L1059). Add focused 404 tests for another user's Set and Exercise when convenient. This is coverage debt; no ownership bypass was found in the reviewed code.

## Concurrency and locking correctness

- `WorkoutSession` is the serialization row for all reviewed lifecycle mutations.
- Under PostgreSQL's normal `READ COMMITTED` isolation, a `SELECT ... FOR UPDATE` that waits behind another transaction sees the committed current row version. `populate_existing=True` refreshes an ORM identity already present in the session.
- If Log Set or Skip acquires the session first, Finish waits for its commit and then checks the updated exercise state. If Finish acquires it first, the mutation waits and then rejects the now-completed session. Neither path holds a child lock while waiting for the session.
- Finish's pending count is performed while holding the session lock. Service-path Log/Skip changes use the same parent lock, so they cannot race between that count and the Finish commit.
- The PostgreSQL pair helpers assert distinct backend PIDs and observe `pg_blocking_pids`; their `finally` blocks release paused workers before executor shutdown: [test_workout_lifecycle.py](../backend/tests/test_workout_lifecycle.py#L373), [test_workout_lifecycle.py](../backend/tests/test_workout_lifecycle.py#L508). The finish-eligible Log/Finish and Skip/Finish tests assert the final persisted state for the serialized order: [test_workout_lifecycle.py](../backend/tests/test_workout_lifecycle.py#L1240), [test_workout_lifecycle.py](../backend/tests/test_workout_lifecycle.py#L1359).

No stale-read, lock bypass, deadlock, or unclosed request transaction was found within the reviewed application paths. Direct SQL writers or future paths that omit the shared session lock can bypass the service-level protocol.

## Regression test quality

- Retry assertions check both response status and persisted `completed_at`, rather than merely asserting no exception.
- Pending Finish checks both HTTP 409 and unchanged session state; ownership and cancelled-status checks verify 404/422 and persisted status.
- Finish-eligible Log/Finish and Skip/Finish tests exercise the shared parent lock and verify allowed/rejected operations and final persisted state.
- The contention tests verify actual PostgreSQL blocking instead of relying only on sleeps. Their cleanup releases workers in `finally`.
- Both negative controls remain meaningful: the unlocked final-set control reproduces an exercise left pending after all sets are completed; the unlocked Log/Skip control forces a stale Log read before Skip commits, then demonstrates the overwritten exercise state: [test_workout_lifecycle.py](../backend/tests/test_workout_lifecycle.py#L1684), [test_workout_lifecycle.py](../backend/tests/test_workout_lifecycle.py#L1763).
- The two P2 coverage limitations are documented above. They do not invalidate the other behavioral and contention assertions.

## Actual validation results

The user reports the following tests were run against PostgreSQL database `forge_workout_test`:

- Workout Lifecycle: **22 passed, 0 failed, 0 skipped**, 2 `StarletteDeprecationWarning`; 6.44 seconds.
- Full Backend Regression: **52 passed, 0 failed, 0 skipped**, 2 `StarletteDeprecationWarning`; 6.29 seconds.
- The user confirms all four Phase 3 regressions, Phase 1 and Phase 2 regressions, and both negative controls passed.

These are user-provided results; they were not run or independently reproduced in the Copilot environment. `git diff --check bbd45b5` passed during this review.

## Remaining risks and limitations

- Row-lock coordination only applies to code paths that follow this service protocol; manual SQL or future code paths can bypass it.
- The database does not enforce the cross-table invariant that a completed session has no pending exercise. The reviewed service paths maintain it through serialization, but no database constraint protects arbitrary writers.
- The tests cover selected PostgreSQL interleavings, not every possible schedule. The Finish/Finish assertion could be made more deterministic as noted under P2.
- Two Starlette deprecation warnings remain in the reported suites; no warning detail was supplied for this review.

## Final commit readiness

**READY**

No P0/P1 production defects were found. The user-reported lifecycle and full backend suites pass on PostgreSQL. The two P2 items are non-blocking test-coverage improvements; they do not contradict the inspected production locking and ownership logic or the reported test results.
