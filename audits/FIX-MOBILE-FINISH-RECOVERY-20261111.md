# FORGE — Flutter Finish Recovery Fix (Phase 4)

**Branch:** `test/workout-mobile-finish-recovery`
**Status:** Phase 4 implementation and validation completed.
**Scope:** Flutter client only. No backend, database, migration, deployment, dependency, or authentication implementation changes.

## Phase 4 baseline

The actual regression baseline supplied for this phase was:

- Focused recovery suite: **8 passed, 5 failed**.
- Full Flutter suite: **19 passed, 5 failed**.

The earlier Phase 3 report's green 8/19 counts are historical results from before the five deterministic concurrency/latency regressions were included; they are not Phase 4 results.

## Five baseline failures and causes

1. **Stale `refresh()` restored a finished workout.** An in-flight current-workout GET could publish its captured `in_progress` response after Finish had cleared the active workout; it had no current-read revision or generation check.
2. **Stale `_reloadCurrent()` restored a finished workout.** The log/skip reload published current state unconditionally after awaiting the GET, with the same ordering defect as `refresh()`.
3. **Pending history delayed summary navigation.** `finishWorkout()` awaited `getHistory()` before returning the completed session to the screen.
4. **Background-history-failure test observed navigation too late.** Although history failure was separated from mutation failure, the Finish future still waited for that history GET; the screen therefore could not navigate while its response gate remained closed.
5. **Out-of-order history response erased the completed item.** A refresh started earlier could publish its old history list after Finish had upserted the completed workout, replacing the newer list.

The regressions are in [workout_finish_recovery_test.dart](../mobile/test/features/workout/workout_finish_recovery_test.dart#L398), [stale reload test](../mobile/test/features/workout/workout_finish_recovery_test.dart#L449), [pending history test](../mobile/test/features/workout/workout_finish_recovery_test.dart#L493), [background failure test](../mobile/test/features/workout/workout_finish_recovery_test.dart#L557), and [history ordering test](../mobile/test/features/workout/workout_finish_recovery_test.dart#L635).

## Production changes

- [workout_controller.dart](../mobile/lib/features/workout/presentation/workout_controller.dart#L56) now maintains separate current-read revision/generation and history-read generation scopes. The Finish transition invalidates pre-existing current and history requests. Current reads publish only if their captured current revision and request generation remain current. History writes publish only for the latest history request generation.
- The controller tracks confirmed completed summaries by workout ID. Stale current responses for those IDs are suppressed, while a different, genuinely newer active workout is preserved. History responses are deduplicated and merged with confirmed completions, so old history cannot erase a known completion and duplicate IDs cannot survive an upsert.
- [finishWorkout](../mobile/lib/features/workout/presentation/workout_controller.dart#L126) validates matching ID and `completed` status, clears only the matching active session, retains/upserts the completed summary, and invalidates progress/adaptation providers before starting history synchronization. It returns the completed session without awaiting that GET.
- Background history success or failure is handled inside the asynchronous operation. Failures are classified as repository (`WorkoutException`) versus unexpected errors and stored in `historySyncError`; confirmed completion is retained. Riverpod 3.4.3's installed `Ref.mounted` API was verified and is checked before post-await state writes.
- [WorkoutSessionScreen](../mobile/lib/features/workout/presentation/workout_session_screen.dart#L360) navigates only after completion is confirmed and no longer attempts to show a history warning on the outgoing route.
- [WorkoutHistoryDetailScreen](../mobile/lib/features/workout/presentation/workout_history_detail_screen.dart#L22) watches the controller state. A later history failure appears as a persistent banner with a **REFRESH HISTORY** action that calls `refresh()` only; it does not send Finish again.
- [workout_repository.dart](../mobile/lib/features/workout/data/workout_repository.dart#L151) retains the prior transport/HTTP classification: response-bearing errors are not mistaken for ambiguous transport failures.

## Ordering and lifecycle strategy

Current-workout reads capture both the current revision and current-read generation. Confirmed completion, Start publication, and a valid current-read publication advance the relevant current revision; a newer read generation excludes an older overlapping read. This scopes invalidation to current-workout ordering rather than unrelated history/error fields.

History reads use their own monotonically increasing generation. Confirmed completion advances that generation before starting its background GET, so older history responses cannot publish afterward. Every successful history publication merges the controller's known completed summaries by ID. History-only updates retain the latest active workout rather than replacing it.

The background task is launched without awaiting it, but its entire asynchronous body catches repository and unexpected failures. It does not retry, and it checks `ref.mounted` before publishing. Mutation and reload paths also avoid starting or publishing follow-up work after provider disposal.

## Recovery guarantees retained

- A response-less connection/timeout error permits at most one same-ID reconciliation GET.
- HTTP errors do not trigger reconciliation.
- A completed reconciliation result permits success navigation; an in-progress result preserves logged sets and allows explicit retry.
- Unknown outcomes preserve last-known state.
- No automatic Finish retry, Start request, duplicate workout creation, or duplicate summary navigation is introduced.
- Existing API authentication/token-refresh behavior is unchanged.

## Test adaptation

All 13 recovery tests remain, including the original eight and the five concurrency/latency regressions. Assertions were not weakened. The existing history-failure controller test now gates the background history request and waits for the warning-state `Completer`, because the Finish future correctly returns before that request completes. Widget gate pumping now advances frames until the existing response gate signals; the post-navigation refresh is run through `WidgetTester.runAsync` to drive the fake HTTP request outside the widget test's paused async zone. These changes preserve checks for pending history, warning visibility, successful refresh, cleared active state, and exactly one Finish request.

## Actual validation

Commands were run from `mobile` after the final production/test edits:

- `dart format` on the five changed Dart files — **PASS**, 0 files changed.
- `dart format --output=none --set-exit-if-changed` on the same files — **PASS**, 0 files changed.
- Targeted `flutter analyze` on the repository, controller, session screen, detail screen, and recovery test — **PASS**, no issues found.
- `flutter test test\features\workout\workout_finish_recovery_test.dart --timeout 60s -r expanded` — **PASS, 13/13**.
- `flutter test --timeout 120s -r expanded` — **PASS, 24/24**.
- `git diff --check` — **PASS**, no tracked whitespace errors.

These are actual runs after the Phase 4 fix, not the baseline or earlier historical results. The untracked test/report files were also checked for trailing whitespace before finalization.

## Remaining risks

- Fake-adapter tests cannot establish real device/socket timing or backend transaction behavior.
- A response-bearing HTTP 5xx after a server-side commit remains outside ambiguous-transport reconciliation; the existing policy is intentionally unchanged.
- The confirmed-completion map is scoped to the controller's in-memory lifetime. Provider recreation relies on the server's current/history endpoints to return authoritative data.

## Commit readiness

**READY FOR REVIEW.** All five Phase 4 regressions, the previous recovery tests, and the full Flutter suite pass. No commit, merge, or push was performed.
