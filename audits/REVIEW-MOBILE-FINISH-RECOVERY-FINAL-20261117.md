# FORGE — Phase 4 Final Code Review After Blocker Fixes

**Branch:** `test/workout-mobile-finish-recovery`
**Base:** `190258ef3f52c66c09e685ba812dab2b28e3c9dd`
**Follow-up:** The P1 identified in the original review was fixed and regression-tested on 17 November 2026. This report incorporates that implementation and its validation.

## 1. Reviewed files

Reviewed against the base commit:

- [workout_controller.dart](../mobile/lib/features/workout/presentation/workout_controller.dart) — full working file and complete production diff.
- [workout_session_screen.dart](../mobile/lib/features/workout/presentation/workout_session_screen.dart) — Finish flow and full production diff.
- [workout_history_detail_screen.dart](../mobile/lib/features/workout/presentation/workout_history_detail_screen.dart) — warning and refresh UI, full production diff.
- [workout_repository.dart](../mobile/lib/features/workout/data/workout_repository.dart) — error classification and full production diff.
- [program_detail_screen.dart](../mobile/lib/features/program/presentation/program_detail_screen.dart) — Start availability guard and retry UI for initial status errors.
- [workout_finish_recovery_test.dart](../mobile/test/features/workout/workout_finish_recovery_test.dart) — all 17 recovery and race tests plus the in-memory backend/gates. It is untracked and absent from the base tree, so ordinary `git diff` does not show it.
- Relevant call sites in [program_detail_screen.dart](../mobile/lib/features/program/presentation/program_detail_screen.dart) and [home_screen.dart](../mobile/lib/features/home/presentation/home_screen.dart).
- [api_client.dart](../mobile/lib/core/api/api_client.dart) — auth-refresh behavior; no diff from the base.
- The requested prior review, fix, and validation reports, including the final Phase 4 fix and validation reports.

The base commit is `HEAD`. The tracked production diff contains five files: repository, controller, session screen, history detail screen, and Program Detail. The recovery test and requested report files are untracked and were inspected separately. Other pre-existing untracked workspace items were not read or modified.

## 2. Verification of the previous blockers

### Stale current-workout reads — RESOLVED for `refresh()` and `_reloadCurrent()`

- `refresh()` captures `_currentRevision` and `_currentReadGeneration` and writes the current result only if both still match ([controller](../mobile/lib/features/workout/presentation/workout_controller.dart#L233), guard at [line 298](../mobile/lib/features/workout/presentation/workout_controller.dart#L298)).
- `_reloadCurrent()` uses the same guard ([controller](../mobile/lib/features/workout/presentation/workout_controller.dart#L273)).
- Confirmed Finish increments the current revision/generation before clearing the matching workout; it also records the completed ID so a later same-ID `in_progress` response is filtered ([controller](../mobile/lib/features/workout/presentation/workout_controller.dart#L179)).
- The guards are scoped: history-only writes preserve the latest active workout, while current-workout writes preserve history and `historySyncError`. A different active workout is not cleared by Finish for the completed ID.
- The deterministic stale-refresh and stale-reload tests release the held response only after Finish has published, then assert the current workout remains null ([tests](../mobile/test/features/workout/workout_finish_recovery_test.dart#L400), [line 451](../mobile/test/features/workout/workout_finish_recovery_test.dart#L451)).

### History ordering — RESOLVED for overlapping history reads

History requests receive their own generation. Finish invalidates any earlier history request before it starts a new synchronization, and history publication checks that generation ([controller](../mobile/lib/features/workout/presentation/workout_controller.dart#L207), [history guard](../mobile/lib/features/workout/presentation/workout_controller.dart#L342)). `_mergeConfirmedHistory` deduplicates by workout ID and overlays confirmed summaries ([controller](../mobile/lib/features/workout/presentation/workout_controller.dart#L424)). The late-response test holds an older refresh, publishes Finish, then releases the old response and checks the completed ID remains exactly once ([test](../mobile/test/features/workout/workout_finish_recovery_test.dart#L855)).

### History blocking navigation — RESOLVED

After validating matching ID and `completed` status, Finish publishes the completion and invalidates progress/adaptation, starts a separate history future, and returns without awaiting it ([controller](../mobile/lib/features/workout/presentation/workout_controller.dart#L179)). The session screen navigates after receiving the completed result ([screen](../mobile/lib/features/workout/presentation/workout_session_screen.dart#L354)). A response gate remains closed while the test checks navigation and cleared current state ([test](../mobile/test/features/workout/workout_finish_recovery_test.dart#L495)).

These two prior blockers are genuinely resolved in the inspected code, not just inferred from green test results.

## 3. State revision/generation correctness

The scopes are appropriately separate for the covered request paths:

- `_currentRevision` changes on Start publication, confirmed Finish, and accepted current reads.
- `_currentReadGeneration` gives overlapping `refresh()` and `_reloadCurrent()` requests latest-request precedence.
- `_historyReadGeneration` sequences refresh and background history reads independently.
- `refresh()` no longer writes `AsyncLoading` before its requests. Its current-read error path only publishes `AsyncError` when the request is still current and no state value exists, so an older refresh cannot replace a newer Finish with Loading/Error.
- Current reads and Start preserve known completed history and existing sync warnings. History-only updates retain the latest current workout. A successful current history request clears the warning; stale generations cannot clear it.
- `logSet` and `skipExercise` check `ref.mounted` after their mutation and use guarded `_reloadCurrent()`. Finish checks mounted before reconciliation follow-up and before state publication. Background writes check both `ref.mounted` and history generation.

### Initial `build()` / Start race — RESOLVED

The original finding was confirmed by test-first reproduction: after successful Start, releasing a gated initial current response published a null current workout; a gated initial history failure published `AsyncError` over the successful Start state. The original UI also left Start enabled while availability was unknown.

`build()` now captures `_currentRevision`, `_currentReadGeneration`, and `_historyReadGeneration`. On success it uses the fetched current workout only if the current revision and generation still match; otherwise it merges the latest published current workout. History is accepted or retained under its independent generation ([controller](../mobile/lib/features/workout/presentation/workout_controller.dart#L62)). If a request fails after a newer relevant state has been published, `build()` returns a copy of that state rather than throwing an obsolete error. A genuine initial-load error with no newer relevant state is still rethrown with its original stack trace. This guards Riverpod's automatic publication of the `build()` Future result, rather than only skipping a side effect.

This distinction is required by installed Riverpod 3.4.3: `handleFuture` retains a running callback that publishes the build result (`riverpod-3.4.3/lib/src/core/element.dart:211-227`); manual `state = AsyncData(...)` does not cancel it (`riverpod-3.4.3/lib/src/core/provider/notifier_provider.dart:90-94`, `riverpod-3.4.3/lib/src/core/element.dart:1449`).

The controller race is tested directly while Start is invoked during initial loading; the UI guard is additional protection. Program Detail disables Start until the provider has a value and shows a retry action if the initial availability check fails ([screen](../mobile/lib/features/program/presentation/program_detail_screen.dart#L101), [retry banner](../mobile/lib/features/program/presentation/program_detail_screen.dart#L137), [Start guard](../mobile/lib/features/program/presentation/program_detail_screen.dart#L172)). The four added tests cover stale success, stale error, genuine initial-load error retention, and this loading guard ([tests](../mobile/test/features/workout/workout_finish_recovery_test.dart#L638), [line 704](../mobile/test/features/workout/workout_finish_recovery_test.dart#L704), [line 769](../mobile/test/features/workout/workout_finish_recovery_test.dart#L769), [line 802](../mobile/test/features/workout/workout_finish_recovery_test.dart#L802)).

## 4. Non-blocking history correctness

- Confirmed Finish does not await the History GET. `getHistory()` is started after the completion state and provider invalidations are published; only the background helper awaits its Future ([controller](../mobile/lib/features/workout/presentation/workout_controller.dart#L226), [helper](../mobile/lib/features/workout/presentation/workout_controller.dart#L322)).
- `WorkoutException` and unexpected errors are both caught inside `_synchronizeHistory`; the task is passed to `unawaited` only after the request future has been created. No exception path intentionally escapes the background Future.
- The failure handler retains completed history/current state and publishes a distinct `historySyncError`. It does not retry and does not send Finish or Start.
- All state writes after awaits check `ref.mounted`; history writes additionally reject stale generations. The provider is a non-auto-dispose `AsyncNotifierProvider` by default, so normal route replacement does not itself discard this state. Explicit invalidation/provider recreation resets the in-memory confirmed-completion map and warning; the next `build()` relies on server state.
- A latest successful history response clears the warning. Current-only/Start/Finish state publications preserve it. A stale history response cannot clear it because its generation no longer matches.

## 5. UI warning and navigation

The session screen has no history SnackBar before navigation and still checks `mounted` before using its context after the Finish Future ([session screen](../mobile/lib/features/workout/presentation/workout_session_screen.dart#L354)). It validates completed status and navigates once via `pushReplacement` ([line 367](../mobile/lib/features/workout/presentation/workout_session_screen.dart#L367)).

The summary/detail screen watches controller state and renders an inline `MaterialBanner` with **REFRESH HISTORY** when a sync error arrives ([detail screen](../mobile/lib/features/workout/presentation/workout_history_detail_screen.dart#L22), [banner](../mobile/lib/features/workout/presentation/workout_history_detail_screen.dart#L69)). Its callback invokes `refresh()` and contains no Finish call. This makes the warning visible after navigation and avoids a stale session-screen context or duplicate SnackBar.

## 6. Regression tests and `WidgetTester.runAsync`

The recovery file now contains 17 tests: the 13 existing recovery cases plus four initial-build/Start regression cases. The 11 pre-existing Flutter tests remain tracked in the auth regression and widget smoke-test files; the full suite now has 28 tests.

- Current and history response gates capture server snapshots at request start and release them through Completers ([backend gates](../mobile/test/features/workout/workout_finish_recovery_test.dart#L978)). The stale current tests await the gate, confirm Finish, release in `finally`, and await the refresh/skip Future. The out-of-order history test awaits its older refresh after releasing its gate.
- The navigation tests wait for the history gate to start, check route replacement/current clearing before releasing it, then release and await gate completion ([tests](../mobile/test/features/workout/workout_finish_recovery_test.dart#L495), [line 559](../mobile/test/features/workout/workout_finish_recovery_test.dart#L559)). `_pumpUntilGateStarted` pumps bounded test frames and throws if the response gate never starts ([helper](../mobile/test/features/workout/workout_finish_recovery_test.dart#L945)); it does not use a wall-clock sleep.
- The history-failure widget test awaits `WidgetTester.runAsync` around the controller's real refresh Future ([test](../mobile/test/features/workout/workout_finish_recovery_test.dart#L618)). This does not bypass its post-refresh assertions; it allows Dio's asynchronous request to finish outside the paused widget-test async zone. The test asserts the warning text/button, no test exception, unchanged one-Finish count, cleared current state, and preserved completed history.
- **Coverage caveat:** the test verifies the **REFRESH HISTORY** button is rendered but calls `controller.refresh()` directly rather than tapping that button. The callback is simple and visibly wired to `refresh()`, but its widget interaction is not itself exercised.
- No assertion was removed or weakened. The two race tests call `startWorkout()` directly while the initial build is gated, so the UI guard does not mask controller correctness. The UI test taps a disabled Start button before releasing its gate and verifies it becomes enabled only after availability is loaded. Existing environment teardown releases response gates, disposes the provider container, and closes both Dio instances ([teardown](../mobile/test/features/workout/workout_finish_recovery_test.dart#L1206)). Background history errors are caught, and disposed refs are checked before state writes.

## 7. Findings by severity

### P0 — Critical production defects

None found.

### P1 — Serious production defects

None remain in the reviewed scope. The initial-build/Start race identified in the original review is resolved and covered by deterministic controller and widget tests (Section 3).

### P2 — Non-blocking issues / coverage improvements

1. **Response-bearing 5xx after server commit remains ambiguous.** The repository classifies any response-bearing Dio exception as `httpResponse`, while only response-less connection/timeout types become `transport` ([repository](../mobile/lib/features/workout/data/workout_repository.dart#L151)). Therefore a commit followed by HTTP 5xx is not reconciled; Finish propagates an error and the prior active state can remain. This is a conservative policy, but its server semantics should remain an explicit product/API risk.
2. **Transport classification lacks direct Finish tests for every type.** `connectionError`, `connectionTimeout`, `sendTimeout`, and `receiveTimeout` without a response all map to transport and permit one same-ID reconciliation. The tests use `receiveTimeout` for lost Finish response and `connectionError` for other requests; they do not individually verify Finish behavior for all four. `unknown`, cancellation, bad certificate, and response-less `badResponse` remain `unexpected` and do not reconcile. Coverage and adapter-specific semantics remain unverified.
3. **Refresh-button interaction is not tapped by the widget test.** The test verifies visibility and separately calls the notifier method, so it does not catch a future callback wiring regression.
4. **Refresh is sequentially coupled to current-workout GET.** If the initial current GET in `refresh()` fails while state already contains data, the catch does not publish an error (`state.value != null`) and returns before requesting history ([controller](../mobile/lib/features/workout/presentation/workout_controller.dart#L242)). The warning remains, but the user receives no distinct indication that this refresh attempt failed and no history GET is attempted.
5. **Device/network and provider-recreation behavior.** The fake Dio adapter does not validate real sockets, OS lifecycle, or request cancellation. `historySyncError` and `_confirmedCompletions` are in-memory; explicit provider recreation/process restart loses the warning/map and relies on server current/history responses.

## 8. Actual validation evidence

Actual final runs after the initial-build fix and regression tests:

- `dart format` on all six changed Dart files — **PASS**.
- `dart format --output=none --set-exit-if-changed` on all six — **PASS**, no changed files.
- Targeted `flutter analyze` on all six — **PASS**, no issues found.
- Focused recovery tests — **PASS, 17/17**.
- Full Flutter suite — **PASS, 28/28**.
- The test-first runs before the production fix failed both direct controller races as expected. The UI test also proved Start was enabled during initial loading. After the guard/fix, the focused suite and full suite passed.
- `git diff --check 190258e` — **PASS** after the report updates; the four follow-up reports also passed a trailing-whitespace scan.

The previously recorded 13/13 focused and 24/24 full results are historical Phase 4 validation before the four new regression cases were added. The original diagnostic timeout was caused by an early test synchronization issue; it was corrected without weakening assertions before the final test-first and post-fix runs.

## 9. Remaining risks

- Fake Dio and widget tests do not model real device/network timing or process suspension.
- HTTP 5xx after a commit is not recovered; no backend semantics were exercised.
- Individual Dio transport types are classified by code but not all covered by Finish-specific tests; adapter/runtime behavior may vary.
- Live network, device lifecycle, and background completion after app suspension were not exercised.
- Provider recreation loses the in-memory warning/completion cache and depends on a successful authoritative server read.
- A latest-started read that fails can invalidate an older overlapping successful read by generation; current/history state then remains at its last published value. This is conservative latest-request-wins behavior and has no dedicated failure-order test.

## 10. Commit readiness

**READY FOR REVIEW.** Both original Phase 4 blockers and the follow-up initial-build/Start race are resolved in production code and covered by deterministic tests. Focused tests (17/17), full Flutter tests (28/28), analyzer, formatting, and whitespace checks passed. No commit, merge, or push was performed.

## 11. Exact files recommended for staging

The exact relevant feature/report files to stage after normal review are:

1. `mobile/lib/features/program/presentation/program_detail_screen.dart`
2. `mobile/lib/features/workout/data/workout_repository.dart`
3. `mobile/lib/features/workout/presentation/workout_controller.dart`
4. `mobile/lib/features/workout/presentation/workout_history_detail_screen.dart`
5. `mobile/lib/features/workout/presentation/workout_session_screen.dart`
6. `mobile/test/features/workout/workout_finish_recovery_test.dart`
7. `audits/FIX-MOBILE-FINISH-RECOVERY-20261111.md`
8. `audits/FIX-MOBILE-FINISH-RECOVERY-FINAL-20261111.md`
9. `audits/VALIDATION-MOBILE-FINISH-RECOVERY-20261111.md`
10. `audits/VALIDATION-MOBILE-FINISH-RECOVERY-FINAL-20261111.md`
11. `audits/REVIEW-MOBILE-FINISH-RECOVERY-FINAL-20261117.md`
12. `audits/FIX-MOBILE-INITIAL-BUILD-START-RACE-20261117.md`

This is a recommendation only; no files were staged. Unrelated existing untracked workspace files are excluded.
