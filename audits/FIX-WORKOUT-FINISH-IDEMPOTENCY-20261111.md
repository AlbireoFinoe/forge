# FORGE — Workout Finish Idempotency Fix

## Baseline and root causes

The implementation was reviewed against `bbd45b59fec2c19a367dacf76fbd5ed1d7d612d4`. The user-provided pre-fix PostgreSQL result was 18 passed and 4 failed out of 22: Finish retry returned 422, concurrent Finish could return different completion timestamps, and Finish did not serialize with Log Set or Skip.

## Production changes

- Added an ownership-filtered `WorkoutSession` `SELECT ... FOR UPDATE` helper using `populate_existing=True`.
- Finish locks and refreshes the session before checking status. Completed sessions return their persisted data without assigning a new completion timestamp; pending exercises still reject completion.
- Skip and Log Set discover the owner-scoped parent IDs, lock and refresh the session, check its refreshed status, then lock and refresh the exercise. Log Set refreshes the set before modifying it.
- The shared lock order is `WorkoutSession` → `WorkoutExercise`; Finish uses the session lock before reading pending-exercise state.

Implementation references: [workout_service.py](../backend/app/services/workout_service.py#L275), [workout_service.py](../backend/app/services/workout_service.py#L324), [workout_service.py](../backend/app/services/workout_service.py#L489), [workout_service.py](../backend/app/services/workout_service.py#L549), [workout_service.py](../backend/app/services/workout_service.py#L647).

## Transaction and API behavior

- The first eligible Finish transitions `in_progress` to `completed` and assigns `completed_at` once.
- A retry for an owned completed session returns the completed representation without assigning a new timestamp.
- Cancelled sessions remain HTTP 422, pending sessions remain HTTP 409, and missing or non-owned sessions remain HTTP 404.
- The service methods roll back on exceptions, including rejected operations. Successful operations commit and refresh before returning.
- Start Workout code was not changed. The source diff is limited to workout lifecycle service helpers/operations; other API, mobile, schema, and migration files were not changed.

## Regression tests

The tests cover sequential retry, lost-response replay, pending-workout rejection, ownership/cancelled state, PostgreSQL concurrent Finish/Finish, Finish/Log, and Finish/Skip. Existing Phase 1/2 tests, negative controls, and direct lock-contention observations remain present: [test_workout_lifecycle.py](../backend/tests/test_workout_lifecycle.py#L940), [test_workout_lifecycle.py](../backend/tests/test_workout_lifecycle.py#L1144), [test_workout_lifecycle.py](../backend/tests/test_workout_lifecycle.py#L1240), [test_workout_lifecycle.py](../backend/tests/test_workout_lifecycle.py#L1359), [test_workout_lifecycle.py](../backend/tests/test_workout_lifecycle.py#L1684), [test_workout_lifecycle.py](../backend/tests/test_workout_lifecycle.py#L1763), [test_workout_lifecycle.py](../backend/tests/test_workout_lifecycle.py#L1842).

The concurrent Finish/Finish test has a non-blocking determinism limitation: its start barrier does not guarantee both transactions have observed the pre-finish row before one proceeds, and it does not directly observe lock contention. This is recorded as a P2 test-quality finding in [REVIEW-WORKOUT-FINISH-IDEMPOTENCY-20261111.md](./REVIEW-WORKOUT-FINISH-IDEMPOTENCY-20261111.md).

## Actual validation

The user reports the following PostgreSQL results on `forge_workout_test`:

- Workout Lifecycle: **22 passed, 0 failed, 0 skipped**, 2 `StarletteDeprecationWarning`; 6.44 seconds.
- Full Backend Regression: **52 passed, 0 failed, 0 skipped**, 2 `StarletteDeprecationWarning`; 6.29 seconds.
- User confirms all four Phase 3 regressions, Phase 1/2 tests, and both negative controls passed.

These are user-run results, not tests executed or independently reproduced in the Copilot environment. `git diff --check bbd45b5` passed during review.

## Remaining limitations

The locking contract covers the service mutation paths reviewed here. Direct SQL writers or future paths that mutate workout rows without the shared parent lock can bypass this protocol. The tests cover selected PostgreSQL interleavings, not every schedule.

## Status

The reported regression suites pass. See the final code review report for the severity assessment and commit readiness.
