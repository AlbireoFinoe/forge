# FORGE — Phase 4 Final Fix Report: Workout Finish Recovery

**Branch:** `test/workout-mobile-finish-recovery`
**Date:** 17 November 2026
**Implementation:** Flutter client only. No backend, database, migration, dependency, or deployment changes.

## 1. Five baseline regression failures

The actual pre-fix Phase 4 baseline was **8 passed / 5 failed** in the focused recovery suite and **19 passed / 5 failed** in the full Flutter suite:

1. Stale `refresh()` restored an `in_progress` session after confirmed Finish.
2. Stale `_reloadCurrent()` from the log/skip path restored that session after confirmed Finish.
3. Finish summary navigation waited for `getHistory()` even after completion was confirmed.
4. The background-history-failure test could not observe navigation before the held history GET finished, for the same blocking reason.
5. An older history response replaced the newer state and erased the known completed history entry.

The deterministic tests are at [workout_finish_recovery_test.dart:398](../mobile/test/features/workout/workout_finish_recovery_test.dart#L398), [line 449](../mobile/test/features/workout/workout_finish_recovery_test.dart#L449), [line 493](../mobile/test/features/workout/workout_finish_recovery_test.dart#L493), [line 557](../mobile/test/features/workout/workout_finish_recovery_test.dart#L557), and [line 635](../mobile/test/features/workout/workout_finish_recovery_test.dart#L635).

## 2. Root cause of each failure

- Failures 1 and 2: current-workout reads published unconditionally after their asynchronous GETs; there was no request ordering guard tied to Finish.
- Failures 3 and 4: `finishWorkout()` awaited history synchronization before returning its confirmed result, making an unrelated GET part of the navigation critical path.
- Failure 5: history refresh replaced the list with its captured response, without a history request generation or merge of known completed summaries.

## 3. Production files changed

- [mobile/lib/features/workout/data/workout_repository.dart](../mobile/lib/features/workout/data/workout_repository.dart#L6) — retains typed HTTP/transport exception classification used by recovery.
- [mobile/lib/features/workout/presentation/workout_controller.dart](../mobile/lib/features/workout/presentation/workout_controller.dart#L56) — current/history ordering, completion preservation, non-blocking history synchronization, disposal/error handling.
- [mobile/lib/features/workout/presentation/workout_session_screen.dart](../mobile/lib/features/workout/presentation/workout_session_screen.dart#L360) — validates completed result and navigates without a pre-navigation history warning.
- [mobile/lib/features/workout/presentation/workout_history_detail_screen.dart](../mobile/lib/features/workout/presentation/workout_history_detail_screen.dart#L22) — destination warning and actionable history refresh.

## 4. State revision/generation strategy

The controller uses `_currentRevision` and `_currentReadGeneration` for current-workout state, plus `_historyReadGeneration` for history. A current GET captures its current revision and request generation before awaiting; it publishes only if both still match. Confirmed Finish invalidates earlier current reads. A valid current-read publication advances the revision, and Start publication invalidates earlier current reads as well.

History uses an independent generation. Finish invalidates old history reads before launching its own request. Only the current history generation can publish, so unrelated current state changes do not discard valid history results and vice versa.

## 5. Protection against stale current-workout reads

`refresh()` and `_reloadCurrent()` use the same `_canPublishCurrent` guard. The controller also tracks confirmed completions by workout ID; a stale response for a completed ID is filtered even if it is received through a later read. Completion clears only the matching active workout, retaining a different active workout if one is genuinely newer. Current-read publications preserve history/error state rather than constructing state from a stale snapshot.

## 6. Protection against stale history responses

Each history fetch has a generation token. Finish advances the token before starting background synchronization, invalidating prior refreshes. `_mergeConfirmedHistory` deduplicates entries by workout ID and overlays every known confirmed completed summary on top of a response. History writes preserve the latest active workout, so a response cannot clear a newer active session.

## 7. Non-blocking history synchronization

`finishWorkout()` validates matching workout ID and `completed` status, immediately publishes completion, clears only the matching active workout, merges its summary, and invalidates progress/adaptation. It starts `getHistory()` in a separate, guarded async operation and returns the completed session without awaiting that GET ([controller](../mobile/lib/features/workout/presentation/workout_controller.dart#L126)).

## 8. Provider lifecycle and async exception handling

The installed dependency is Riverpod 3.4.3 (`flutter_riverpod` and `riverpod` in `mobile/pubspec.lock`). Its `Ref.mounted` API was verified in the installed package source. Background writes, current/history publication, Finish recovery, and post-mutation reload paths avoid using disposed provider state.

The background operation catches `WorkoutException` separately from unexpected exceptions inside its own async body. It records an explicit `historySyncError`; therefore `unawaited` cannot drop an unhandled future error. It performs no automatic retry and retains confirmed completion on either error path.

## 9. User-visible history synchronization warning

The outgoing session screen no longer shows the sync warning before route replacement. The summary/detail screen watches `workoutControllerProvider`; a later failure appears as a persistent `MaterialBanner` with a **REFRESH HISTORY** action. That action calls controller `refresh()` and does not send Finish again ([detail screen](../mobile/lib/features/workout/presentation/workout_history_detail_screen.dart#L22)). It uses no stale or unmounted session-screen `BuildContext`.

## 10. Actual test and static-analysis results

The following are actual final runs after the production and test edits, from `mobile`:

- `dart format` on all five changed Dart files — **PASS**, 0 files changed.
- `dart format --output=none --set-exit-if-changed` on all five files — **PASS**, 0 changed.
- `flutter analyze` on the changed production and regression-test files — **PASS**, no issues found.
- `flutter test test\features\workout\workout_finish_recovery_test.dart --timeout 60s -r expanded` — **PASS, 13/13**.
- `flutter test --timeout 120s -r expanded` — **PASS, 24/24**.
- `git diff --check` — **PASS**; untracked test/report files were separately checked for trailing whitespace.

This is distinct from the supplied pre-fix baseline (**8/5** focused, **19/5** full) and earlier Phase 3 results (**8/0**, **19/0**) from before the five new regressions existed.

## 11. Remaining risks and limitations

- In-memory adapter tests cannot prove real device/socket timing or backend transaction semantics.
- A response-bearing HTTP 5xx after a server-side commit is not reconciled under the existing response-less transport policy.
- Confirmed summaries are retained in controller memory for its lifetime; after provider recreation, correctness depends on authoritative server current/history responses.

No automatic Finish retry, Start request, duplicate workout creation, or duplicate navigation was introduced. Existing authentication/token-refresh behavior was not changed.

## 12. Commit readiness

**READY FOR REVIEW.** All five Phase 4 regressions, the eight prior recovery tests, and all 11 existing Flutter tests pass. Formatting, analyzer, and whitespace validation are clean. No commit, merge, or push was performed.

## Follow-up fix — initial build / Start ordering (17 November 2026)

The readiness statement above records the earlier Phase 4 state and predates the P1 found in the final review. The P1 has now been fixed and validated; this follow-up supersedes that earlier scope/status.

### Root cause and Riverpod publication behavior

`WorkoutController.build()` returned a Future based on its captured current/history responses. In Riverpod 3.4.3, the provider continues listening for that Future's result and publishes it on completion (`riverpod-3.4.3/lib/src/core/element.dart:211-227`). A manual `state = AsyncData(...)` in `startWorkout()` does not cancel the build Future (`riverpod-3.4.3/lib/src/core/provider/notifier_provider.dart:90-94`; `element.dart:1449`). Consequently, a late initial null-current result or error replaced the successful Start state.

### Implementation strategy

The initial build captures `_currentRevision`, `_currentReadGeneration`, and `_historyReadGeneration` at entry ([controller](../mobile/lib/features/workout/presentation/workout_controller.dart#L62)). It publishes fetched current only if the current revision and generation remain current. Otherwise, it returns the latest published current workout; history is independently accepted only while its history generation remains current. This uses the Future's actual return value as the publication boundary rather than attempting an ineffective side-effect-only guard.

If a current/history request fails after a newer relevant state has been published, `build()` returns that latest state instead of allowing an obsolete `AsyncError` to replace it. A genuine initial-load failure with no newer relevant state is still rethrown with its original stack trace. `ref.mounted` is checked before reading provider state after awaits, and Riverpod cancels publication on disposal.

Program Detail now disables Start until `workoutControllerProvider` has a value and shows a retry action when initial status loading fails ([screen](../mobile/lib/features/program/presentation/program_detail_screen.dart#L101), [retry banner](../mobile/lib/features/program/presentation/program_detail_screen.dart#L137), [button guard](../mobile/lib/features/program/presentation/program_detail_screen.dart#L172)). The controller fix is independently tested by calling Start while the initial requests remain gated. A Material surface was added inside the decorated day card so Flutter's ListTile ink assertion does not obstruct the UI regression test ([screen](../mobile/lib/features/program/presentation/program_detail_screen.dart#L357)).

### Test-first and final evidence

Before the production fix, both deterministic controller tests failed: the initial build's late empty-current response erased the started ID, and its late history failure published `AsyncError`. The UI test independently confirmed the Start callback was enabled while availability was unknown. The tests use Completers and response gates, with no arbitrary wall-clock sleeps. The four added tests are at [stale initial success](../mobile/test/features/workout/workout_finish_recovery_test.dart#L638), [stale initial error](../mobile/test/features/workout/workout_finish_recovery_test.dart#L704), [genuine initial failure](../mobile/test/features/workout/workout_finish_recovery_test.dart#L769), and [Program Detail loading guard](../mobile/test/features/workout/workout_finish_recovery_test.dart#L802).

Actual final runs after the fix:

- `dart format` and `dart format --output=none --set-exit-if-changed` on all six changed Dart files — **PASS**.
- Targeted `flutter analyze` on all six changed Dart files — **PASS**, no issues found.
- Focused Finish recovery suite — **PASS, 17/17**.
- Full Flutter suite — **PASS, 28/28**.
- `git diff --check 190258e` — **PASS** after the report updates; the four follow-up reports also passed a trailing-whitespace scan.

No backend, dependency, database, migration, or deployment changes were made. There are no automatic Start/Finish retries or provider invalidation loops.

### Current follow-up status

**READY FOR REVIEW.** The final whitespace/diff checks passed. No commit, merge, or push was performed.
