# FORGE — Phase 4 Final Commit Readiness Verification

**Branch:** `test/workout-mobile-finish-recovery`
**Base / HEAD:** `190258ef3f52c66c09e685ba812dab2b28e3c9dd`
**Review date:** 17 November 2026
**Mode:** Read-only source/test review. This report is the only file created for this verification.

## 1. Scope and evidence

Read the requested [initial build / Start fix report](FIX-MOBILE-INITIAL-BUILD-START-RACE-20261117.md), [final recovery review](REVIEW-MOBILE-FINISH-RECOVERY-FINAL-20261117.md), and [final recovery validation](VALIDATION-MOBILE-FINISH-RECOVERY-FINAL-20261111.md).

Inspected the full [WorkoutController](../mobile/lib/features/workout/presentation/workout_controller.dart), [Program Detail screen](../mobile/lib/features/program/presentation/program_detail_screen.dart), [WorkoutRepository](../mobile/lib/features/workout/data/workout_repository.dart), [history detail screen](../mobile/lib/features/workout/presentation/workout_history_detail_screen.dart), Finish/navigation flow in [workout_session_screen.dart](../mobile/lib/features/workout/presentation/workout_session_screen.dart), and the complete 17-test [workout_finish_recovery_test.dart](../mobile/test/features/workout/workout_finish_recovery_test.dart). Verified the installed Riverpod source and lockfile version: Riverpod 3.4.3. The current HEAD equals the stated base; no files were staged.

## 2. Previous blockers

| Blocker | Status | Direct evidence |
|---|---|---|
| Stale `refresh()` restores a completed workout | **RESOLVED** | `refresh()` captures revision/generation and only publishes through `_canPublishCurrent` ([controller](../mobile/lib/features/workout/presentation/workout_controller.dart#L233), [guard](../mobile/lib/features/workout/presentation/workout_controller.dart#L298)); deterministic test [line 400](../mobile/test/features/workout/workout_finish_recovery_test.dart#L400). |
| Stale `_reloadCurrent()` restores a completed workout | **RESOLVED** | `_reloadCurrent()` uses the same scoped guard ([controller](../mobile/lib/features/workout/presentation/workout_controller.dart#L273)); skip/reload race test [line 451](../mobile/test/features/workout/workout_finish_recovery_test.dart#L451). |
| Finish waits for history before summary navigation | **RESOLVED** | Finish publishes completion, invalidates progress/adaptation, starts a caught history task, and returns without awaiting it ([controller](../mobile/lib/features/workout/presentation/workout_controller.dart#L179), [background sync](../mobile/lib/features/workout/presentation/workout_controller.dart#L322)); the gated navigation test checks navigation before releasing history ([test](../mobile/test/features/workout/workout_finish_recovery_test.dart#L495)). |
| Initial `build()` overwrites successful Start with stale data or `AsyncError` | **RESOLVED** | Build captures current revision/generation and independent history generation; it returns current latest state for a stale scope and rethrows only errors still relevant to the active scope ([controller](../mobile/lib/features/workout/presentation/workout_controller.dart#L62)). The two direct gated regressions are at [line 638](../mobile/test/features/workout/workout_finish_recovery_test.dart#L638) and [line 704](../mobile/test/features/workout/workout_finish_recovery_test.dart#L704). |

## 3. Initial build and mutation ordering

The Riverpod behavior in the fix report is borne out by installed 3.4.3 source: `handleFuture` attaches success/error callbacks that publish a still-running build Future (`riverpod-3.4.3/lib/src/core/element.dart:211-227`). A manual notifier state assignment delegates to `setValueFromState` and does not cancel that callback (`riverpod-3.4.3/lib/src/core/provider/notifier_provider.dart:90-94`; `element.dart:1449`).

The production handling closes that publication path, not just a side effect:

- `build()` snapshots `_currentRevision` and increments/captures `_currentReadGeneration` and `_historyReadGeneration` before awaiting either request ([controller](../mobile/lib/features/workout/presentation/workout_controller.dart#L62)).
- On success, the current result is used only while both current tokens match. If Start, Finish, or another accepted current read advanced the scope, the build result carries forward `state.value?.currentWorkout`. History is separately selected by history generation and always merged with `_confirmedCompletions`.
- If an error arrives after a newer relevant state, the build returns a copy of that state instead of emitting stale `AsyncError`. `currentReadCompleted` distinguishes a current-read failure from a later history failure. If no relevant scope changed, the original error and stack trace are rethrown ([controller](../mobile/lib/features/workout/presentation/workout_controller.dart#L66), [error branch](../mobile/lib/features/workout/presentation/workout_controller.dart#L102)).
- `startWorkout()` advances the current revision and read generation before publishing the response ([controller](../mobile/lib/features/workout/presentation/workout_controller.dart#L125)). Finish advances current and history ordering before clearing only the matching workout and starting history sync ([controller](../mobile/lib/features/workout/presentation/workout_controller.dart#L179)).

### Latest-mutation loss check

I found **no concrete remaining lost-update interleaving** in the inspected implementation. If a mutation publishes before the initial build's post-await token check, its revision/generation change is observed and the build returns the latest state. The token comparison, synchronous state selection, and return occur in one Dart isolate continuation with no intervening `await`; a mutation continuation cannot execute in the middle of that sequence. If a mutation completes afterward, its own publication advances the revision and writes its newer state. Current and history are guarded independently, so a valid history update is not rejected merely because the current workout changed, nor vice versa. A stale build also takes the latest state for a superseded scope instead of replacing it with a captured null/current/history snapshot.

The tests deterministically cover Start succeeding before a gated initial empty response and before a gated initial history error. A genuine initial history failure without a newer mutation remains `AsyncError` ([test](../mobile/test/features/workout/workout_finish_recovery_test.dart#L769)). This review does not infer a defect solely from the absence of an additional test for every possible scheduler interleaving.

## 4. Genuine errors and Start UI guard

Initial errors remain observable when their request is still current. Program Detail disables Start when the provider has no value, including initial loading/error states; an initial status error displays a **RETRY** action that calls `refresh()` rather than Start ([screen](../mobile/lib/features/program/presentation/program_detail_screen.dart#L101), [retry banner](../mobile/lib/features/program/presentation/program_detail_screen.dart#L137), [Start guard](../mobile/lib/features/program/presentation/program_detail_screen.dart#L172)).

The UI guard does not keep Start disabled after availability is known. The widget test first verifies a null callback while the initial current response is gated, then releases the gate and verifies Start is enabled when the resulting state confirms there is no active workout ([test](../mobile/test/features/workout/workout_finish_recovery_test.dart#L802)). The controller race tests independently call `startWorkout()` during initial loading, so UI disabling does not conceal controller behavior.

## 5. Finish/history, exceptions, and disposal

- Finish validates matching ID and `completed` status before it publishes completion. It clears only the matching current workout, preserves/deduplicates the completed summary, invalidates progress/adaptation, and does not await History GET ([controller](../mobile/lib/features/workout/presentation/workout_controller.dart#L179)).
- The background task handles `WorkoutException` and unexpected exceptions inside `_synchronizeHistory`, reports `historySyncError`, and does not retry. History results and errors publish only for the current `_historyReadGeneration` ([sync](../mobile/lib/features/workout/presentation/workout_controller.dart#L322), [publication guard](../mobile/lib/features/workout/presentation/workout_controller.dart#L342)).
- State writes after async work check `ref.mounted`; Riverpod 3.4.3 defines this API in `lib/src/core/ref.dart:112`. On disposal, `handleFuture` cancels its publication callback (`element.dart:211-255`); the controller itself does not write after a failed mounted check.
- The summary destination watches the history warning and exposes **REFRESH HISTORY**; this action refreshes state/history and does not send Finish ([detail screen](../mobile/lib/features/workout/presentation/workout_history_detail_screen.dart#L22), [banner](../mobile/lib/features/workout/presentation/workout_history_detail_screen.dart#L69)). The widget test verifies navigation before the held GET is released, then failure visibility and refresh without another Finish ([test](../mobile/test/features/workout/workout_finish_recovery_test.dart#L559)).

## 6. Test harness correctness

The inspected file has **17 tests**: the prior 13 recovery tests plus four initial-build/Start tests. Assertions remain meaningful and the previous 13 remain present.

- Current/history response gates snapshot the fake server response and release via `Completer`; the helper pumps bounded test frames until the gate starts ([gate helper](../mobile/test/features/workout/workout_finish_recovery_test.dart#L945), [backend gate methods](../mobile/test/features/workout/workout_finish_recovery_test.dart#L978)).
- The Start success test asserts the returned workout ID/status, final current state, no null publication after Start, exactly one Start request, and the expected session count.
- The stale-error test observes provider state and asserts the successful Start remains `in_progress`, with no stale `AsyncError`; the genuine-error test independently verifies a current initial failure remains observable.
- The loading-guard test checks `onPressed == null`, taps while disabled, verifies no Start request, releases the gate, then checks the callback becomes available.
- Existing stale refresh/reload tests assert completion and retained logged data. Existing Finish tests cover bounded same-ID reconciliation, no automatic Start, explicit retry, and no duplicate navigation. History latency/failure tests use response gates and assert destination state before/after release.
- The history-warning test uses `WidgetTester.runAsync` only for the refresh request's real async Future; its state, Finish-count, and history assertions run after the await. The race tests themselves use no `runAsync` and no wall-clock sleeps. Teardown releases pending gates before disposing the provider container and closing Dio ([teardown](../mobile/test/features/workout/workout_finish_recovery_test.dart#L1206)).

## 7. Findings

### P0 — Critical

**None found.**

### P1 — Blocking

**None found.** No concrete unresolved blocker was found in the initial build, Start, Finish/history, or disposal paths reviewed.

### P2 — Non-blocking technical debt / coverage

1. **Response-bearing HTTP 5xx after server commit.** Repository classification treats any response-bearing Dio error as `httpResponse`, while response-less connection/timeout errors are transport (`workout_repository.dart:151-160`). A server commit followed by a 5xx is not reconciled under the current policy; backend semantics were not inspected here.
2. **Finish-specific transport coverage is partial.** The tests exercise a lost response and connection failure but do not individually exercise all connection/send/receive timeout types; cancellation, bad certificate, and unknown error classification also remain outside the reconciliation path.
3. **History refresh interaction coverage.** The test verifies the destination's **REFRESH HISTORY** button and separately calls `refresh()`; it does not tap that button itself.
4. **Refresh failure behavior.** If `refresh()`'s current-workout GET fails while state already has a value, it returns before requesting history and does not replace the known data with a new error ([controller](../mobile/lib/features/workout/presentation/workout_controller.dart#L233)). This preserves known state but gives no separate result for that attempted refresh.
5. **Runtime lifecycle coverage.** Fake Dio tests do not cover real sockets, device suspension, process death, or provider recreation; confirmed-completion/error caches are in memory.

These are coverage or API/runtime limitations, not P0/P1 findings in the reviewed scope.

## 8. Validation evidence

The latest validation supplied for this verification reports:

- Focused Finish recovery tests: **17/17 passed**.
- Full Flutter suite: **28/28 passed**.
- Analyzer, Dart format, and whitespace checks: **passed**.

I did **not** rerun tests, analyzer, formatter, or whitespace checks during this read-only verification. The results above are attributed to the latest supplied validation, not to this review session.

## 9. Exact files for staging

Stage only the relevant feature/test/report files below after normal commit review; do not stage unrelated existing untracked workspace items:

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
13. `audits/REVIEW-MOBILE-PHASE4-COMMIT-READINESS-20261117.md`

No files were staged, committed, merged, or pushed during this verification.

## 10. Final decision

**READY FOR COMMIT.** All prior blockers are resolved by direct code inspection and deterministic regression tests. No P0/P1 production defect or concrete latest-mutation-loss interleaving was found. Remaining items are P2 technical debt and test/runtime coverage limitations listed above.
