# FORGE — Initial Build / Start Workout Race Fix

**Branch:** `test/workout-mobile-finish-recovery`
**Base commit:** `190258e`
**Date:** 17 November 2026
**Scope:** Flutter client only. No backend, database, migration, dependency, or deployment changes.

## 1. P1 root cause

`WorkoutController.build()` awaited the initial current-workout and history requests, then returned their captured values. Riverpod 3.4.3 continues listening to the asynchronous `build()` Future and publishes its eventual value or error. A successful `startWorkout()` manually wrote newer `AsyncData`, but that write did not cancel the still-running build Future. Thus:

- a late initial current response reporting no workout could clear the successfully started workout; or
- a late initial history failure could publish `AsyncError` over the successful Start state.

The UI made the race reachable because Program Detail treated `workoutState.value?.currentWorkout == null` during initial loading like confirmed workout absence and left Start enabled.

## 2. Test-first regression evidence

Added deterministic regression tests to [workout_finish_recovery_test.dart](../mobile/test/features/workout/workout_finish_recovery_test.dart):

1. **Late initial success:** gate initial current/history responses, call controller `startWorkout()` directly, then release the older response. Before the fix, the final current workout ID was null instead of the started ID. The test verifies started ID/status, no stale null publication, one Start request, and one created session for that Start ([test](../mobile/test/features/workout/workout_finish_recovery_test.dart#L638)).
2. **Late initial error:** gate initial current/history, successfully Start, then release history with a simulated connection failure. Before the fix, the provider published `AsyncError` ([test](../mobile/test/features/workout/workout_finish_recovery_test.dart#L704)).
3. **Genuine initial-load failure:** without a newer mutation, an initial history error remains visible as `AsyncError` ([test](../mobile/test/features/workout/workout_finish_recovery_test.dart#L769)).
4. **Program Detail loading guard:** with the initial current response held, Start's `onPressed` must be null and tapping it must not send a Start request. It becomes enabled after availability is loaded ([test](../mobile/test/features/workout/workout_finish_recovery_test.dart#L802)).

Before the production fix, the first two tests failed on the actual stale null/error state. The UI test independently found an enabled Start callback during initial loading. The initial widget-test attempt also exposed a Flutter ListTile/Material ink assertion; a Material surface was added inside the decorated day card so the interaction test exercises the UI without that framework exception.

The tests use the existing fake Dio response gates and Completers. The Start races invoke the controller directly while those gates remain held, so the UI guard does not hide a controller defect. The widget gate starts through bounded test-frame pumping; no arbitrary wall-clock sleep was introduced. No existing assertion was removed or weakened.

## 3. Riverpod initial build publication behavior

The installed dependency is Riverpod 3.4.3 (`mobile/pubspec.lock`). Its `handleFuture` attaches success/error callbacks to the build Future and publishes the eventual result while the request is still running (`riverpod-3.4.3/lib/src/core/element.dart:211-227`). The manual notifier state setter delegates to `setValueFromState` (`riverpod-3.4.3/lib/src/core/provider/notifier_provider.dart:90-94`; `riverpod-3.4.3/lib/src/core/element.dart:1449`) and does not cancel those callbacks.

Therefore, a guard that only suppresses side effects is insufficient: `build()` must resolve to a state that is still valid, and stale failures must not escape to Riverpod as `AsyncError`.

## 4. Selected implementation strategy

[WorkoutController.build](../mobile/lib/features/workout/presentation/workout_controller.dart#L62) captures `_currentRevision`, `_currentReadGeneration`, and `_historyReadGeneration` before awaiting requests.

- Current workout is taken from the initial response only if both its revision and read generation are still current.
- Otherwise, the build result carries forward the latest published current workout.
- History is independently accepted only while its history generation remains current; otherwise, the latest published history is retained and confirmed completions are merged.
- The result is returned through Riverpod's actual build Future publication path, avoiding a rebuild or invalidate loop.
- A caught failure is suppressed only when the relevant request scope has become stale and newer state exists. `currentReadCompleted` distinguishes a current-read failure from a later history failure. If no newer relevant state exists, the original error and stack trace are rethrown, preserving genuine initial-load error behavior.
- `ref.mounted` is checked before reading provider state after awaits. A disposed provider is not manually updated.

Successful Start retains its existing current revision/read-generation invalidation and publishes the successful session ([controller](../mobile/lib/features/workout/presentation/workout_controller.dart#L125)). When an older build later finishes, it can no longer replace that session or its in-progress status.

## 5. Production and test files changed

Production files changed against the base:

- [mobile/lib/features/workout/presentation/workout_controller.dart](../mobile/lib/features/workout/presentation/workout_controller.dart#L62)
- [mobile/lib/features/program/presentation/program_detail_screen.dart](../mobile/lib/features/program/presentation/program_detail_screen.dart#L101)
- [mobile/lib/features/workout/data/workout_repository.dart](../mobile/lib/features/workout/data/workout_repository.dart)
- [mobile/lib/features/workout/presentation/workout_session_screen.dart](../mobile/lib/features/workout/presentation/workout_session_screen.dart)
- [mobile/lib/features/workout/presentation/workout_history_detail_screen.dart](../mobile/lib/features/workout/presentation/workout_history_detail_screen.dart)

The latter three retain the previously implemented Phase 4 recovery, non-blocking history, and destination warning behavior; they were not broadened for this race fix.

Test file changed:

- [mobile/test/features/workout/workout_finish_recovery_test.dart](../mobile/test/features/workout/workout_finish_recovery_test.dart#L638) — four focused tests added; all 13 prior recovery tests remain.

## 6. How successful Start is protected

The revision and current-read generation advance when Start publishes, invalidating a current response captured before Start. The initial build checks those tokens before selecting current state and returns the latest published Start result when stale. The deterministic test confirms the workout ID returned by Start remains current and `in_progress`, Start is called once, and no null state is published after successful Start.

The guard also covers a failure after successful Start: the stale build returns the newer state rather than publishing `AsyncError`. It does not send another Start or Finish request.

## 7. Initial build failure handling

Initial errors remain errors when there is no newer relevant state. The dedicated genuine-load-failure test verifies the provider remains `AsyncError` with a `WorkoutException`. When a newer current/history state supersedes the request, the old error is converted into the latest valid data state. This maintains observable genuine load failures without letting an obsolete error roll back a successful mutation.

## 8. UI loading protection

Program Detail now considers availability known only when `workoutControllerProvider.value` is non-null. Start stays disabled during the initial loading state and after an initial-load error. If the first status request fails with no prior value, a **RETRY** banner calls `refresh()`; it does not invoke Start. Once refresh provides a state, Start is enabled only if no active workout exists.

A transparent Material surface inside the decorated day card fixes the ListTile ink assertion encountered by the widget regression test; it preserves the card decoration and permits normal ink rendering.

## 9. Actual validation results

Actual final runs after production and test changes:

- `dart format` on all six changed Dart files — **PASS**.
- `dart format --output=none --set-exit-if-changed` on all six — **PASS**, no changed files.
- Targeted `flutter analyze` on all six — **PASS**, no issues found.
- `flutter test test\features\workout\workout_finish_recovery_test.dart --timeout 60s -r expanded` — **PASS, 17/17** (13 existing + four new).
- `flutter test --timeout 120s -r expanded` — **PASS, 28/28**.
- `git diff --check 190258e` — **PASS** after report updates; all four follow-up reports also passed a trailing-whitespace scan.

The original 13/13 focused and 24/24 full results were historical runs before the four new regression tests were added. The results above are the latest actual executions.

## 10. Remaining risks

- Fake Dio gates verify deterministic ordering but do not model live sockets, device lifecycle, app suspension, or backend transaction timing.
- A response-bearing HTTP 5xx after a server-side commit remains outside the existing response-less transport reconciliation policy.
- In-memory completion/error state still relies on authoritative current/history responses after provider recreation.
- Concurrent-read failures, token refresh, and normal Finish/history recovery are covered by the existing focused/full suites, but no real-device network test was run.

## 11. Commit readiness

**READY FOR REVIEW.** The initial-build/Start P1 is deterministically reproduced before the fix and passes after it; all prior recovery tests remain green. Whitespace/diff checks passed. No files were staged, committed, merged, or pushed.
