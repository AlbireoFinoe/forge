# FORGE — Workout Finish Idempotency Validation

## Environment and scope

- Branch: `test/workout-finish-idempotency`
- Implementation baseline: `bbd45b59fec2c19a367dacf76fbd5ed1d7d612d4`
- PostgreSQL database used by the user: `forge_workout_test`
- The results below were supplied by the user. They were not executed or independently reproduced in the Copilot environment.

## Actual post-change validation

| Suite | Passed | Failed | Skipped | Warnings | Runtime |
|---|---:|---:|---:|---|---:|
| Workout Lifecycle | 22 | 0 | 0 | 2 `StarletteDeprecationWarning` | 6.44 s |
| Full Backend Regression | 52 | 0 | 0 | 2 `StarletteDeprecationWarning` | 6.29 s |

The user reports that all four Phase 3 regressions which failed before the fix now pass. Phase 1 and Phase 2 regression tests, including both negative controls, also remain passing. These are user-run PostgreSQL results, not Copilot-run results.

## Coverage reviewed

- Sequential retry after completion and lost-response retry assert a successful completed response and unchanged `completed_at`: [test_workout_lifecycle.py](../backend/tests/test_workout_lifecycle.py#L940), [test_workout_lifecycle.py](../backend/tests/test_workout_lifecycle.py#L986).
- Pending exercises remain a 409 and leave the session in progress with no completion timestamp: [test_workout_lifecycle.py](../backend/tests/test_workout_lifecycle.py#L1032).
- Finish ownership and cancelled-session behavior: [test_workout_lifecycle.py](../backend/tests/test_workout_lifecycle.py#L1059).
- PostgreSQL concurrent Finish/Finish, Finish/Log Set, and Finish/Skip: [test_workout_lifecycle.py](../backend/tests/test_workout_lifecycle.py#L1144), [test_workout_lifecycle.py](../backend/tests/test_workout_lifecycle.py#L1240), [test_workout_lifecycle.py](../backend/tests/test_workout_lifecycle.py#L1359).
- Phase 2 contention tests, negative controls, and session-level Finish/Log/Skip serialization remain in the suite: [test_workout_lifecycle.py](../backend/tests/test_workout_lifecycle.py#L1468), [test_workout_lifecycle.py](../backend/tests/test_workout_lifecycle.py#L1684), [test_workout_lifecycle.py](../backend/tests/test_workout_lifecycle.py#L1763), [test_workout_lifecycle.py](../backend/tests/test_workout_lifecycle.py#L1842), [test_workout_lifecycle.py](../backend/tests/test_workout_lifecycle.py#L1927).

## Copilot-environment verification

No tests or database operations were run during this review. The PostgreSQL test results above are attributed to the user. `git diff --check bbd45b5` passed in the review environment.

## Interpretation and limitations

The reported passing PostgreSQL suites verify the implementation against the isolated test database. They do not prove all possible schedules or behavior of direct SQL writers that bypass the workout service's session-lock protocol. The dedicated Finish/Finish assertion has a minor determinism limitation documented in [REVIEW-WORKOUT-FINISH-IDEMPOTENCY-20261111.md](./REVIEW-WORKOUT-FINISH-IDEMPOTENCY-20261111.md).

## Validation status

**User-reported validation: PASS.** The review did not rerun these tests and makes no claim that Copilot independently reproduced them.
