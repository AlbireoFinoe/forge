from dataclasses import dataclass, field

from app.generator.context import GeneratorContext
from app.generator.distribution import (
    VolumeDistributionPlan,
)
from app.generator.exercise_pool import (
    ExerciseCandidate,
)
from app.generator.split import SplitPlan


PRIORITY_WEIGHT = {
    "maintenance": 0.8,
    "normal": 1.0,
    "high": 1.3,
}


DIFFICULTY_RANK = {
    "beginner": 1,
    "intermediate": 2,
    "advanced": 3,
}


MAX_SETS_PER_EXERCISE = 5
MAX_PHYSICAL_SETS_PER_SESSION = 30
DEMAND_TOLERANCE = 0.25
SPILLOVER_CREDIT_FACTOR = 0.50
EXPOSURE_RETENTION_RATIO = {
    "maintenance": 0.75,
    "normal": 0.50,
    "high": 0.60,
}

WEEKLY_OVERSHOOT_PENALTY = {
    "maintenance": 5.0,
    "normal": 4.0,
    "high": 2.5,
}

MIN_RETAINED_EFFECTIVE_SETS = 2.0
PRIMARY_COVERAGE_RESCUE_MIN_WEEKLY_RATIO = {
    "maintenance": 0.80,
    "normal": 0.85,
    "high": 0.90,
}

MAINTENANCE_RESCUE_MAX_EFFECTIVE_SETS = 2.0


@dataclass
class MutableExerciseSelection:
    exercise: ExerciseCandidate
    sets: int = 0
    first_selection_index: int = 0
    reason_codes: set[str] = field(
        default_factory=set
    )


@dataclass(frozen=True)
class SelectedExercise:
    exercise: ExerciseCandidate

    exercise_order: int
    sets: int

    min_reps: int
    max_reps: int
    rest_seconds: int

    reason_codes: tuple[str, ...]


@dataclass(frozen=True)
class SessionExercisePlan:
    day_of_week: int
    day_order: int
    session_name: str

    exercises: tuple[
        SelectedExercise,
        ...
    ]

    target_effective_sets: dict[
        str,
        float,
    ]

    achieved_effective_sets: dict[
        str,
        float,
    ]

    remaining_effective_sets: dict[
        str,
        float,
    ]

    physical_sets: int


@dataclass(frozen=True)
class ExerciseSelectionPlan:
    sessions: tuple[
        SessionExercisePlan,
        ...
    ]


class ExerciseSelectorError(Exception):
    pass


def _difficulty_allowed(
    context: GeneratorContext,
    exercise: ExerciseCandidate,
) -> bool:

    user_rank = DIFFICULTY_RANK.get(
        context.experience_level,
        1,
    )

    exercise_rank = DIFFICULTY_RANK.get(
        exercise.difficulty,
        1,
    )

    return exercise_rank <= user_rank


def _exercise_relevant(
    exercise: ExerciseCandidate,
    remaining: dict[str, float],
) -> bool:

    return any(
        remaining_value > DEMAND_TOLERANCE
        and exercise.contribution_for(
            muscle_code
        ) > 0
        for muscle_code, remaining_value
        in remaining.items()
    )


def _apply_projected_actual_one_set(
    exercise: ExerciseCandidate,
    projected_weekly_actual: dict[str, float],
) -> None:

    for muscle_code in (
        projected_weekly_actual
    ):
        contribution = (
            exercise.contribution_for(
                muscle_code
            )
        )

        if contribution <= 0:
            continue

        projected_weekly_actual[
            muscle_code
        ] += contribution


def _is_duplicate_isolation_pattern(
    exercise: ExerciseCandidate,
    selected: dict[
        str,
        MutableExerciseSelection,
    ],
) -> bool:
    # Compounds are allowed to coexist.
    # This rule only prevents redundant
    # isolation variations in one session.
    if exercise.is_compound:
        return False

    for item in selected.values():
        existing = item.exercise

        # Re-selecting the exact same
        # exercise simply adds another set.
        if existing.code == exercise.code:
            continue

        if existing.is_compound:
            continue

        if (
            existing.primary_muscle
            == exercise.primary_muscle
            and existing.movement_pattern
            == exercise.movement_pattern
        ):
            return True

    return False


def _score_candidate(
    context: GeneratorContext,
    exercise: ExerciseCandidate,
    remaining: dict[str, float],
    selected: dict[str, MutableExerciseSelection],
    used_movements: set[str],
    weekly_usage: dict[str, int],
    weekly_targets: dict[str, float],
    projected_weekly_actual: dict[str, float],
) -> float:

    score = 0.0
    muscles_helped = 0

    for muscle_code, demand in remaining.items():
        if demand <= DEMAND_TOLERANCE:
            continue

        contribution = exercise.contribution_for(
            muscle_code
        )

        if contribution <= 0:
            continue

        muscles_helped += 1

        priority = (
            context.muscle_priorities.get(
                muscle_code,
                "normal",
            )
        )

        priority_weight = (
            PRIORITY_WEIGHT.get(
                priority,
                1.0,
            )
        )

        useful_contribution = min(
            demand,
            contribution,
        )

        overshoot = max(
            0.0,
            contribution - demand,
        )

        score -= (
            overshoot
            * priority_weight
            * 1.25
        )

        score += (
            useful_contribution
            * priority_weight
            * 3.0
        )

        if (
            exercise.primary_muscle
            == muscle_code
        ):
            score += (
                0.8
                * priority_weight
            )

    # Penalize a candidate when one more
    # physical set pushes any muscle farther
    # beyond its real weekly target.
    for (
        muscle_code,
        weekly_target,
    ) in weekly_targets.items():

        contribution = (
            exercise.contribution_for(
                muscle_code
            )
        )

        if contribution <= 0:
            continue

        actual_before = (
            projected_weekly_actual.get(
                muscle_code,
                0.0,
            )
        )

        actual_after = (
            actual_before
            + contribution
        )

        overshoot_before = max(
            0.0,
            actual_before
            - weekly_target,
        )

        overshoot_after = max(
            0.0,
            actual_after
            - weekly_target,
        )

        added_overshoot = max(
            0.0,
            overshoot_after
            - overshoot_before,
        )

        if added_overshoot <= 0:
            continue

        priority = (
            context.muscle_priorities.get(
                muscle_code,
                "normal",
            )
        )

        penalty_weight = (
            WEEKLY_OVERSHOOT_PENALTY.get(
                priority,
                4.0,
            )
        )

        score -= (
            added_overshoot
            * penalty_weight
        )

    if muscles_helped >= 2:
        score += 1.0

        if exercise.is_compound:
            score += 0.75

    if (
        exercise.movement_pattern
        not in used_movements
    ):
        score += 0.20

    else:
        score -= 0.50

    current_selection = selected.get(
        exercise.code
    )

    if current_selection is not None:
        if current_selection.sets < 3:
            score += 0.90

        elif (
            current_selection.sets
            < MAX_SETS_PER_EXERCISE
        ):
            score += 0.35

        else:
            score -= 100.0

    else:
        # Opening another exercise has a
        # meaningful setup/time cost.
        score -= 0.80

    usage = weekly_usage.get(
        exercise.code,
        0,
    )

    if usage >= 2:
        score -= 0.50 * (
            usage - 1
        )

    return score


def _apply_one_set(
    exercise: ExerciseCandidate,
    remaining: dict[str, float],
    achieved: dict[str, float],
) -> None:

    for muscle_code in remaining:
        contribution = (
            exercise.contribution_for(
                muscle_code
            )
        )

        if contribution <= 0:
            continue

        achieved[muscle_code] += (
            contribution
        )

        remaining[muscle_code] = max(
            0.0,
            remaining[muscle_code]
            - contribution,
        )


def _build_reason_codes(
    context: GeneratorContext,
    exercise: ExerciseCandidate,
    target_muscles: set[str],
) -> set[str]:

    reasons = {
        "EQUIPMENT_MATCH",
    }

    primary_priority = (
        context.muscle_priorities.get(
            exercise.primary_muscle,
            "normal",
        )
    )

    if primary_priority == "high":
        reasons.add(
            "HIGH_PRIORITY_VOLUME"
        )

    if (
        context.arm_specialization
        and exercise.primary_muscle
        in {"BICEPS", "TRICEPS"}
    ):
        reasons.add(
            "ARM_SPECIALIZATION"
        )

    covered_targets = [
        muscle
        for muscle in target_muscles
        if exercise.contribution_for(
            muscle
        ) > 0
    ]

    if (
        exercise.is_compound
        and len(covered_targets) >= 2
    ):
        reasons.add(
            "MULTI_MUSCLE_EFFICIENCY"
        )

    return reasons


def _build_weekly_targets(
    distribution: VolumeDistributionPlan,
) -> dict[str, float]:

    targets: dict[str, float] = {}

    for allocation in distribution.allocations:
        targets[
            allocation.muscle_code
        ] = (
            targets.get(
                allocation.muscle_code,
                0.0,
            )
            + allocation.target_effective_sets
        )

    return targets


def _apply_weekly_contribution(
    exercise: ExerciseCandidate,
    weekly_remaining: dict[str, float],
    current_target_muscles: set[str],
) -> None:

    for muscle_code in weekly_remaining:
        contribution = (
            exercise.contribution_for(
                muscle_code
            )
        )

        if contribution <= 0:
            continue

        if (
            muscle_code
            not in current_target_muscles
        ):
            contribution *= (
                SPILLOVER_CREDIT_FACTOR
            )

        weekly_remaining[
            muscle_code
        ] = max(
            0.0,
            weekly_remaining[
                muscle_code
            ] - contribution,
        )


def _needs_primary_coverage_rescue(
    exercise: ExerciseCandidate,
    priority: str,
    targets: dict[str, float],
    achieved: dict[str, float],
    weekly_targets: dict[str, float],
    projected_weekly_actual: dict[str, float],
) -> bool:

    muscle_code = exercise.primary_muscle

    session_target = targets.get(
        muscle_code
    )

    if (
        session_target is None
        or session_target <= DEMAND_TOLERANCE
    ):
        return False

    session_achieved = achieved.get(
        muscle_code,
        0.0,
    )

    # Never force work beyond the amount
    # allocated to the current session.
    if session_achieved >= session_target:
        return False

    weekly_target = weekly_targets.get(
        muscle_code
    )

    if (
        weekly_target is None
        or weekly_target <= DEMAND_TOLERANCE
    ):
        return False

    weekly_floor = (
        weekly_target
        * PRIMARY_COVERAGE_RESCUE_MIN_WEEKLY_RATIO.get(
            priority,
            0.70,
        )
    )

    weekly_achieved = (
        projected_weekly_actual.get(
            muscle_code,
            0.0,
        )
    )

    return weekly_achieved < weekly_floor


def _select_for_session(
    context: GeneratorContext,
    session,
    distribution: VolumeDistributionPlan,
    pool: tuple[
        ExerciseCandidate,
        ...
    ],
    weekly_usage: dict[str, int],
    weekly_remaining: dict[str, float],
    weekly_targets: dict[str, float],
    weekly_actual: dict[str, float],
) -> SessionExercisePlan:

    allocations = [
        allocation
        for allocation
        in distribution.allocations
        if allocation.day_order
        == session.day_order
    ]

    targets = {}

    for allocation in allocations:
        muscle_code = (
            allocation.muscle_code
        )

        scheduled_target = float(
            allocation.target_effective_sets
        )

        priority = (
            context.muscle_priorities.get(
                muscle_code,
                "normal",
            )
        )

        retention_ratio = (
            EXPOSURE_RETENTION_RATIO.get(
                priority,
                0.50,
            )
        )

        weekly_target = (
            weekly_targets.get(
                muscle_code,
                scheduled_target,
            )
        )

        actual_so_far = (
            weekly_actual.get(
                muscle_code,
                0.0,
            )
        )

        actual_remaining = max(
            0.0,
            weekly_target
            - actual_so_far,
        )

        # If real accumulated stimulus has
        # already satisfied this muscle,
        # do not force another exposure.
        if (
            actual_remaining
            <= DEMAND_TOLERANCE
        ):
            continue

        planning_remaining = (
            weekly_remaining.get(
                muscle_code,
                actual_remaining,
            )
        )

        retained_floor = min(
            scheduled_target,
            max(
                MIN_RETAINED_EFFECTIVE_SETS,
                scheduled_target
                * retention_ratio,
            ),
        )

        # Retention may never force more work
        # than the real weekly deficit.
        retained_floor = min(
            retained_floor,
            actual_remaining,
        )

        planning_target = min(
            scheduled_target,
            planning_remaining,
        )

        adjusted_target = min(
            actual_remaining,
            max(
                planning_target,
                retained_floor,
            ),
        )

        if (
            adjusted_target
            > DEMAND_TOLERANCE
        ):
            targets[
                muscle_code
            ] = round(
                adjusted_target,
                2,
            )

    # Rescue unfinished maintenance volume
    # when the current session already
    # supports that muscle.
    #
    # Example:
    # QUADS target = 6
    # earlier session fitted only 4
    # current session also focuses QUADS
    # -> rescue the remaining 2 sets here.
    session_has_scheduled_targets = bool(
        targets
    )

    for muscle_code in (
        session.focus_muscles
    ):
        priority = (
            context
            .muscle_priorities
            .get(
                muscle_code,
                "normal",
            )
        )

        if priority != "maintenance":
            continue

        # Normal scheduled allocation
        # already handles this muscle.
        if muscle_code in targets:
            continue

        future_allocations = [
            allocation
            for allocation
            in distribution.allocations
            if (
                allocation.muscle_code
                == muscle_code
                and allocation.day_order
                > session.day_order
            )
        ]

        # Do not rescue maintenance volume
        # early when this session already
        # has meaningful scheduled work
        # and the muscle still has a future
        # planned exposure.
        #
        # We only rescue early when the
        # current session would otherwise
        # have no scheduled targets at all.
        if (
            future_allocations
            and session_has_scheduled_targets
        ):
            continue

        weekly_target = (
            weekly_targets.get(
                muscle_code
            )
        )

        if weekly_target is None:
            continue

        actual_so_far = (
            weekly_actual.get(
                muscle_code,
                0.0,
            )
        )

        actual_remaining = max(
            0.0,
            weekly_target
            - actual_so_far,
        )

        if (
            actual_remaining
            <= DEMAND_TOLERANCE
        ):
            continue

        planning_remaining = max(
            0.0,
            weekly_remaining.get(
                muscle_code,
                actual_remaining,
            ),
        )

        rescue_target = min(
            (
                MAINTENANCE_RESCUE_MAX_EFFECTIVE_SETS
            ),
            actual_remaining,
            planning_remaining,
        )

        if (
            rescue_target
            > DEMAND_TOLERANCE
        ):
            targets[
                muscle_code
            ] = round(
                rescue_target,
                2,
            )

    targets = {
        muscle: target
        for muscle, target in targets.items()
        if target > DEMAND_TOLERANCE
    }

    target_muscles = set(
        targets
    )

    remaining = dict(
        targets
    )

    achieved = {
        muscle_code: 0.0
        for muscle_code in targets
    }

    projected_weekly_actual = dict(
        weekly_actual
    )

    if not targets:
        return SessionExercisePlan(
            day_of_week=(
                session.day_of_week
            ),
            day_order=(
                session.day_order
            ),
            session_name=(
                session.name
            ),
            exercises=(),
            target_effective_sets={},
            achieved_effective_sets={},
            remaining_effective_sets={},
            physical_sets=0,
        )

    session_candidates = [
        exercise
        for exercise in pool
        if (
            exercise.primary_muscle
            in target_muscles
            and _difficulty_allowed(
                context,
                exercise,
            )
            and _exercise_relevant(
                exercise,
                remaining,
            )
        )
    ]

    if not session_candidates:
        raise ExerciseSelectorError(
            f"No eligible exercises for "
            f"session {session.day_order}"
        )

    selected: dict[
        str,
        MutableExerciseSelection,
    ] = {}

    used_movements: set[str] = set()

    physical_sets = 0
    selection_counter = 0

    while (
        any(
            value > DEMAND_TOLERANCE
            for value in remaining.values()
        )
        and physical_sets
        < MAX_PHYSICAL_SETS_PER_SESSION
    ):
        candidates = [
            exercise
            for exercise in session_candidates
            if (
                exercise.code not in selected
                or selected[
                    exercise.code
                ].sets
                < MAX_SETS_PER_EXERCISE
            )
            and not _is_duplicate_isolation_pattern(
                exercise,
                selected,
            )
            and _exercise_relevant(
                exercise,
                remaining,
            )
        ]

        if not candidates:
            break

        scored = [
            (
                _score_candidate(
                    context=context,
                    exercise=exercise,
                    remaining=remaining,
                    selected=selected,
                    used_movements=(
                        used_movements
                    ),
                    weekly_usage=(
                        weekly_usage
                    ),
                    weekly_targets=(
                        weekly_targets
                    ),
                    projected_weekly_actual=(
                        projected_weekly_actual
                    ),
                ),
                exercise,
            )
            for exercise in candidates
        ]

        scored.sort(
            key=lambda item: (
                -item[0],
                item[1].code,
            )
        )

        best_score, best = scored[0]

        coverage_rescue = False

        if best_score <= 0:
            rescue_candidate = next(
                (
                    (
                        score,
                        exercise,
                    )
                    for score, exercise
                    in scored
                    if _needs_primary_coverage_rescue(
                        exercise=exercise,
                        priority=context.muscle_priorities.get(
                            exercise.primary_muscle,
                            "normal",
                        ),
                        targets=targets,
                        achieved=achieved,
                        weekly_targets=weekly_targets,
                        projected_weekly_actual=(
                            projected_weekly_actual
                        ),
                    )
                ),
                None,
            )

            if rescue_candidate is None:
                break

            best_score, best = (
                rescue_candidate
            )

            coverage_rescue = True

        if best.code not in selected:
            selection_counter += 1

            selected[
                best.code
            ] = MutableExerciseSelection(
                exercise=best,
                sets=0,
                first_selection_index=(
                    selection_counter
                ),
                reason_codes=(
                    _build_reason_codes(
                        context,
                        best,
                        set(targets),
                    )
                ),
            )

        if coverage_rescue:
            selected[
                best.code
            ].reason_codes.add(
                "PRIMARY_COVERAGE_RESCUE"
            )

        selected[
            best.code
        ].sets += 1

        physical_sets += 1

        used_movements.add(
            best.movement_pattern
        )

        _apply_one_set(
            exercise=best,
            remaining=remaining,
            achieved=achieved,
        )

        _apply_projected_actual_one_set(
            exercise=best,
            projected_weekly_actual=(
                projected_weekly_actual
            ),
        )

    selected_items = list(
        selected.values()
    )

    # Compounds first, while preserving
    # deterministic selection order.
    selected_items.sort(
        key=lambda item: (
            not item.exercise.is_compound,
            item.first_selection_index,
            item.exercise.code,
        )
    )

    exercises = []

    for order, item in enumerate(
        selected_items,
        start=1,
    ):
        exercises.append(
            SelectedExercise(
                exercise=item.exercise,
                exercise_order=order,
                sets=item.sets,
                min_reps=(
                    item.exercise.min_reps
                ),
                max_reps=(
                    item.exercise.max_reps
                ),
                rest_seconds=(
                    item.exercise.rest_seconds
                ),
                reason_codes=tuple(
                    sorted(
                        item.reason_codes
                    )
                ),
            )
        )

    return SessionExercisePlan(
        day_of_week=session.day_of_week,
        day_order=session.day_order,
        session_name=session.name,
        exercises=tuple(exercises),
        target_effective_sets=targets,
        achieved_effective_sets={
            muscle: round(
                value,
                2,
            )
            for muscle, value
            in achieved.items()
        },
        remaining_effective_sets={
            muscle: round(
                value,
                2,
            )
            for muscle, value
            in remaining.items()
        },
        physical_sets=physical_sets,
    )


def select_session_exercises(
    context: GeneratorContext,
    session,
    distribution: VolumeDistributionPlan,
    pool: tuple[
        ExerciseCandidate,
        ...
    ],
    weekly_usage: dict[str, int],
    weekly_remaining: dict[str, float],
    weekly_targets: dict[str, float],
    weekly_actual: dict[str, float],
) -> SessionExercisePlan:

    return _select_for_session(
        context=context,
        session=session,
        distribution=distribution,
        pool=pool,
        weekly_usage=weekly_usage,
        weekly_remaining=weekly_remaining,
        weekly_targets=weekly_targets,
        weekly_actual=weekly_actual,
    )


def _apply_selected_session_credit(
    session: SessionExercisePlan,
    weekly_remaining: dict[str, float],
) -> None:

    target_muscles = set(
        session.target_effective_sets
    )

    for selected in session.exercises:
        for _ in range(
            selected.sets
        ):
            _apply_weekly_contribution(
                exercise=(
                    selected.exercise
                ),
                weekly_remaining=(
                    weekly_remaining
                ),
                current_target_muscles=(
                    target_muscles
                ),
            )


def _apply_selected_session_actual(
    session: SessionExercisePlan,
    weekly_actual: dict[str, float],
) -> None:

    for selected in session.exercises:
        candidate = (
            selected.exercise
        )

        for muscle_code in (
            weekly_actual
        ):
            contribution = (
                candidate.contribution_for(
                    muscle_code
                )
                * selected.sets
            )

            if contribution <= 0:
                continue

            weekly_actual[
                muscle_code
            ] += contribution


def _apply_selected_session_usage(
    session: SessionExercisePlan,
    weekly_usage: dict[str, int],
) -> None:

    for selected in session.exercises:
        code = (
            selected.exercise.code
        )

        weekly_usage[code] = (
            weekly_usage.get(
                code,
                0,
            )
            + 1
        )


def select_exercises(
    context: GeneratorContext,
    split_plan: SplitPlan,
    distribution: VolumeDistributionPlan,
    pool: tuple[
        ExerciseCandidate,
        ...
    ],
) -> ExerciseSelectionPlan:

    if not pool:
        raise ExerciseSelectorError(
            "Exercise pool is empty"
        )

    weekly_usage: dict[
        str,
        int,
    ] = {}

    weekly_targets = (
        _build_weekly_targets(
            distribution
        )
    )

    weekly_remaining = dict(
        weekly_targets
    )

    weekly_actual = {
        muscle_code: 0.0
        for muscle_code
        in weekly_targets
    }

    session_plans = []

    for session in split_plan.sessions:
        selected_session = (
            select_session_exercises(
                context=context,
                session=session,
                distribution=distribution,
                pool=pool,
                weekly_usage=weekly_usage,
                weekly_remaining=(
                    weekly_remaining
                ),
                weekly_targets=(
                    weekly_targets
                ),
                weekly_actual=(
                    weekly_actual
                ),
            )
        )

        session_plans.append(
            selected_session
        )

        _apply_selected_session_credit(
            selected_session,
            weekly_remaining,
        )

        _apply_selected_session_actual(
            selected_session,
            weekly_actual,
        )

        _apply_selected_session_usage(
            selected_session,
            weekly_usage,
        )

    return ExerciseSelectionPlan(
        sessions=tuple(
            session_plans
        )
    )