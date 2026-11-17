# FORGE — Flutter Finish Recovery Validation

**Branch:** `test/workout-mobile-finish-recovery`
**Validation date:** 17 November 2026
**Environment:** Flutter 3.47.2 stable; Dart 3.13.2; Riverpod 3.4.3.

## Result timeline

The following results are distinct:

| Stage | Focused recovery tests | Full Flutter suite | Meaning |
| --- | ---: | ---: | --- |
| Before Phase 4 race tests (historical) | 8 passed, 0 failed | 19 passed, 0 failed | Earlier validation, before adding concurrency regressions. |
| Phase 4 regression baseline (historical, supplied) | 8 passed, 5 failed | 19 passed, 5 failed | Five new deterministic tests reproduced the blockers. |
| Phase 4 final code (actual runs) | **13 passed, 0 failed** | **24 passed, 0 failed** | This environment's results after the production fix. |

The five supplied baseline failures were stale `refresh()`, stale `_reloadCurrent()`, history GET delaying navigation, the corresponding navigation-order assertion on background failure, and old history overwriting the completed summary.

## Commands actually run after the fix

All commands ran from `mobile`:

1. `dart format lib\features\workout\data\workout_repository.dart lib\features\workout\presentation\workout_controller.dart lib\features\workout\presentation\workout_session_screen.dart lib\features\workout\presentation\workout_history_detail_screen.dart test\features\workout\workout_finish_recovery_test.dart` — **PASS**, 5 files checked, 0 changed.
2. `dart format --output=none --set-exit-if-changed` on those five files — **PASS**, 0 changed.
3. `flutter analyze` on the same production and test files — **PASS**, no issues found.
4. `flutter test test\features\workout\workout_finish_recovery_test.dart --timeout 60s -r expanded` — **PASS, 13/13**.
5. `flutter test --timeout 120s -r expanded` — **PASS, 24/24**.
6. `git diff --check` — **PASS**; the untracked recovery test and requested report files were checked separately for trailing whitespace.

No dependencies were installed or changed. Test requests used an in-memory Dio adapter; no backend or database was contacted. The existing authentication regression tests are included in the 24 passing full-suite tests.

## Five regression outcomes

1. **Stale refresh after Finish:** Finish invalidates earlier current reads; the held `in_progress` response cannot restore the completed workout ([controller](../mobile/lib/features/workout/presentation/workout_controller.dart#L180), [test](../mobile/test/features/workout/workout_finish_recovery_test.dart#L398)).
2. **Stale log/skip reload after Finish:** `_reloadCurrent()` uses the same revision/generation guard ([controller](../mobile/lib/features/workout/presentation/workout_controller.dart#L220), [test](../mobile/test/features/workout/workout_finish_recovery_test.dart#L449)).
3. **Pending history GET:** Finish publishes the completion and returns before history synchronization; the gated test observes summary navigation while history remains pending ([controller](../mobile/lib/features/workout/presentation/workout_controller.dart#L126), [test](../mobile/test/features/workout/workout_finish_recovery_test.dart#L493)).
4. **Background failure after navigation:** the destination displays `historySyncError` with a refresh action; a history refresh does not send Finish a second time ([detail screen](../mobile/lib/features/workout/presentation/workout_history_detail_screen.dart#L22), [test](../mobile/test/features/workout/workout_finish_recovery_test.dart#L557)).
5. **Out-of-order history:** history generations reject outdated results and merge/deduplicate known completed summaries ([controller](../mobile/lib/features/workout/presentation/workout_controller.dart#L289), [test](../mobile/test/features/workout/workout_finish_recovery_test.dart#L635)).

## Adapted synchronization assertions

No behavioral assertions were removed or weakened. The pre-existing history-failure unit test now holds the background request and awaits a state-listener `Completer`, because the Finish future no longer waits for history. Widget tests pump frames until the fake adapter's response gate starts, then release the gate deterministically. The post-navigation refresh is run through `WidgetTester.runAsync` so the fake Dio request can complete outside the widget test's paused async zone. This preserves the original contract checks and verifies that the warning remains actionable after navigation.

## Recovery and lifecycle checks

- Finish and reconciliation still require matching workout ID and `completed` status before clearing the active session.
- Only response-less connection/timeout exceptions are ambiguous; HTTP responses remain separately classified ([repository](../mobile/lib/features/workout/data/workout_repository.dart#L151)).
- Lost responses trigger at most one same-ID reconciliation GET; no automatic Finish retry or Start request was added.
- Background history failures are caught and classified, retain confirmed completion, and publish only while the Riverpod 3.4.3 `ref.mounted` check is true.
- Current reads and history reads use independent ordering scopes, so a valid update to one scope is not rejected merely because an unrelated field changed.

## Limitations

Tests cannot prove live socket timing or backend transaction semantics. HTTP 5xx after a commit is not reconciled by the existing response-less transport policy. Provider recreation depends on server responses being authoritative.

## Conclusion

**VALIDATED — READY FOR REVIEW.** The actual final focused result is **13/13** and the actual full-suite result is **24/24**; formatting and targeted analysis are clean. The historical 8/19 counts are clearly separated from these final executions.
