# FORGE — Flutter Finish Recovery Final Regression Validation

**Branch:** `test/workout-mobile-finish-recovery`
**Validation date:** 17 November 2026
**Purpose:** Record the five Phase 4 race/latency regressions, their production resolution, and actual final validation.

## Baseline and five failures

The supplied Phase 4 baseline was **8 passed / 5 failed** for focused recovery tests and **19 passed / 5 failed** for the full suite. These five deterministic tests were the failures:

1. **Stale refresh after confirmed Finish.** An older `getCurrentWorkout()` result published `in_progress` after Finish cleared the matching active session.
2. **Stale `_reloadCurrent()` after confirmed Finish.** A log/skip-triggered reload similarly published its old active-session snapshot after completion.
3. **History synchronization blocked navigation.** `finishWorkout()` awaited `getHistory()` before returning the completed workout.
4. **Background history failure navigation-order assertion.** The same awaited history request prevented navigation before the held GET was released, even though its eventual failure was a history-sync error rather than a Finish failure.
5. **Out-of-order history overwrote completion.** A refresh started earlier published a stale list after Finish had inserted the known completed summary.

The corresponding assertions are in [stale refresh](../mobile/test/features/workout/workout_finish_recovery_test.dart#L398), [stale reload](../mobile/test/features/workout/workout_finish_recovery_test.dart#L449), [pending history/navigation](../mobile/test/features/workout/workout_finish_recovery_test.dart#L493), [background failure/navigation order](../mobile/test/features/workout/workout_finish_recovery_test.dart#L557), and [history ordering](../mobile/test/features/workout/workout_finish_recovery_test.dart#L635).

## Implemented ordering design

[WorkoutController](../mobile/lib/features/workout/presentation/workout_controller.dart#L56) uses separate ordering scopes:

- Current-workout GETs capture `_currentRevision` and `_currentReadGeneration`. Finish and other current-state publications advance the relevant scope; a response publishes only if both captured values are still current.
- History GETs use `_historyReadGeneration`. Finish invalidates in-flight history work before starting its own background synchronization. Only the newest history request may publish.
- Confirmed completed summaries are retained by ID and merged/deduplicated into later history responses. Old current responses for a known completed ID are suppressed. History-only updates retain the latest current workout, including a different, genuinely newer active workout.

This avoids a single global revision that would incorrectly discard a valid history or current-workout update because an unrelated field changed.

## Non-blocking Finish and background sync

After a matching Finish POST or same-ID reconciliation confirms `completed`, the controller validates the ID/status, immediately publishes completion, clears only the matching active workout, preserves/upserts history, invalidates progress/adaptation, starts a separate history request, and returns the completed workout ([controller](../mobile/lib/features/workout/presentation/workout_controller.dart#L126)).

The background operation catches repository and unexpected failures within its own async body. It records a separate `historySyncError`, never rolls back completion, does not retry, and publishes only if the history generation is current and `ref.mounted` is true. The installed Riverpod version was verified as 3.4.3; its `Ref.mounted` lifecycle API exists in the locked package.

The session screen navigates only on a completed result. The destination summary/detail screen watches controller state and shows a persistent warning with a **REFRESH HISTORY** action; that action refreshes state/history and never resends Finish ([detail screen](../mobile/lib/features/workout/presentation/workout_history_detail_screen.dart#L22)).

## Test synchronization

The five original race/latency regressions and the prior eight recovery tests are all retained. No behavioral assertion was weakened.

The pre-existing history-failure unit test now holds the background GET and awaits a state listener's `Completer`, because the Finish call correctly returns before the GET finishes. Widget response-gate tests pump frames until the fake adapter signals request start. The post-navigation refresh is executed through `WidgetTester.runAsync`, which allows its fake HTTP request to complete outside the widget test's paused async zone. These are deterministic gate/state waits, not arbitrary delays.

## Actual final command results

Commands ran from `mobile` after the final production and test edits:

- `dart format` on all five changed Dart files — **PASS**, 0 changes.
- `dart format --output=none --set-exit-if-changed` on all five files — **PASS**, 0 changes.
- Targeted `flutter analyze` on all changed production/test Dart files — **PASS**, no issues found.
- `flutter test test\features\workout\workout_finish_recovery_test.dart --timeout 60s -r expanded` — **PASS, 13/13**.
- `flutter test --timeout 120s -r expanded` — **PASS, 24/24**.
- `git diff --check` — **PASS**; new untracked regression/report files were separately checked for trailing whitespace.

The earlier Phase 4 attempt of **8 passed / 5 failed** focused and **19 passed / 5 failed** full is the pre-fix baseline, not a final result. Earlier Phase 3 reports of 8/19 all passing predate the five regressions and are historical only.

## Acceptance status

- [x] Stale `refresh()` cannot restore the completed session.
- [x] Stale `_reloadCurrent()` cannot restore the completed session.
- [x] Summary navigation occurs while the history response is pending.
- [x] A later history failure remains visible/actionable on the destination.
- [x] History refresh does not invoke Finish again.
- [x] Older history cannot erase a known completion; duplicate IDs are removed.
- [x] Recovery remains bounded, same-ID, and mutation-safe.
- [x] 13/13 focused and 24/24 full Flutter tests pass.
- [x] Targeted analyzer and formatting checks pass.

## Remaining limitations

The fake adapter cannot validate live-network timing, device lifecycle, or backend/database transaction behavior. Response-bearing HTTP 5xx after a commit remains outside the existing transport-only reconciliation rule. A provider recreated after disposal relies on the server's current/history endpoints for prior completions.

## Final status

**VALIDATED — READY FOR REVIEW.** No backend, dependency, database, migration, or deployment changes were made. No commit, merge, or push was performed.

## Follow-up validation — initial build / Start race (17 November 2026)

The original 13/13 focused and 24/24 full-suite results above are the actual Phase 4 validation before the initial-build race tests were added. They remain historical results; the following later runs supersede them for the current worktree.

### Test-first evidence

Before changing production code, deterministic tests held the initial current/history responses with the existing fake Dio gates:

- The initial-current response completed after a successful `startWorkout()`. The old `build()` then published a null current workout; the test failed because the expected started ID was null.
- A gated initial history request failed after Start succeeded. Riverpod published the old build failure over the new state; the test observed `AsyncError`.
- Program Detail rendered Start with an enabled `onPressed` while current-workout availability was still loading. After adding a test-side pump until the request gate started, the assertion failed with an enabled callback. The first widget run also surfaced Flutter's ListTile/Material assertion; a local Material surface was added around the day tile.

The final pre-fix run of both controller regressions failed on those actual state values. The test synchronization was corrected to observe the error publication and request start; no behavioral assertions were weakened. Tests invoke `startWorkout()` directly while the build remains gated, so the UI guard does not mask the controller race.

### Actual post-fix executions

Run from `mobile` after the controller, UI, and regression-test changes:

- `dart format` on all six changed Dart files — **PASS**, no remaining edits on the final run.
- `dart format --output=none --set-exit-if-changed` on all six changed Dart files — **PASS**.
- Targeted `flutter analyze` on all six changed Dart files — **PASS**, no issues found.
- `flutter test test\features\workout\workout_finish_recovery_test.dart --timeout 60s -r expanded` — **PASS, 17/17** (the prior 13 plus four new tests).
- `flutter test --timeout 120s -r expanded` — **PASS, 28/28** (the previous 24 plus four new tests).
- `git diff --check 190258e` — **PASS** after the report updates; the four follow-up reports also passed a trailing-whitespace scan.

The tests cover stale initial success, stale initial error, retention of a genuine initial-load error when no newer state exists, and the Program Detail loading guard. Existing Finish recovery, refresh/reload ordering, non-blocking history, background warning, and history deduplication tests remain unchanged and passing.

No backend, dependency, database, migration, or deployment configuration was changed. No files were staged, committed, merged, or pushed.
