from dataclasses import dataclass

from app.generator.context import GeneratorContext
from app.generator.fatigue import (
    training_capacity_factor,
)
from app.generator.selector import (
    ExerciseSelectionPlan,
    SelectedExercise,
    SessionExercisePlan,
)


SET_EXECUTION_SECONDS = 40
EXERCISE_TRANSITION_SECONDS = 75
WARMUP_SECONDS = 8 * 60

MIN_SETS_PER_EXERCISE = 2
MIN_EFFECTIVE_COVERAGE = 2.0


PRIORITY_WEIGHT = {
    "maintenance": 0.8,
    "normal": 1.0,
    "high": 1.35,
}


@dataclass(frozen=True)
class FittedExercise:
    exercise: SelectedExercise
    sets: int


@dataclass(frozen=True)
class FittedSessionPlan:
    day_of_week: int
    day_order: int
    session_name: str

    exercises: tuple[
        FittedExercise,
        ...
    ]

    physical_sets: int

    estimated_duration_minutes: int
    available_duration_minutes: int

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

    reason_codes: tuple[str, ...]


@dataclass(frozen=True)
class FittedProgramPlan:
    sessions: tuple[
        FittedSessionPlan,
        ...
    ]


class DurationFitterError(Exception):
    pass


def _exercise_seconds(
    selected: SelectedExercise,
    sets: int,
) -> int:

    if sets <= 0:
        return 0

    work_time = (
        sets
        * SET_EXECUTION_SECONDS
    )

    rest_time = (
        max(
            0,
            sets - 1,
        )
        * selected.rest_seconds
    )

    return (
        work_time
        + rest_time
        + EXERCISE_TRANSITION_SECONDS
    )


def _session_seconds(
    exercises: list[
        FittedExercise
    ],
) -> int:

    return (
        WARMUP_SECONDS
        + sum(
            _exercise_seconds(
                item.exercise,
                item.sets,
            )
            for item in exercises
        )
    )


def _recalculate_achievement(
    session: SessionExercisePlan,
    exercises: list[
        FittedExercise
    ],
):
    achieved = {
        muscle: 0.0
        for muscle
        in session.target_effective_sets
    }

    for item in exercises:
        candidate = (
            item.exercise.exercise
        )

        for muscle in achieved:
            contribution = (
                candidate.contribution_for(
                    muscle
                )
            )

            if contribution <= 0:
                continue

            achieved[muscle] += (
                contribution
                * item.sets
            )

    remaining = {
        muscle: max(
            0.0,
            target
            - achieved[muscle],
        )
        for muscle, target
        in session.target_effective_sets.items()
    }

    return (
        {
            muscle: round(
                value,
                2,
            )
            for muscle, value
            in achieved.items()
        },
        {
            muscle: round(
                value,
                2,
            )
            for muscle, value
            in remaining.items()
        },
    )


def _exercise_utility(
    context: GeneratorContext,
    session: SessionExercisePlan,
    item: FittedExercise,
) -> float:

    exercise = (
        item.exercise.exercise
    )

    utility = 0.0

    for (
        muscle,
        target,
    ) in session.target_effective_sets.items():

        contribution = (
            exercise.contribution_for(
                muscle
            )
        )

        if contribution <= 0:
            continue

        priority = (
            context.muscle_priorities.get(
                muscle,
                "normal",
            )
        )

        priority_weight = (
            PRIORITY_WEIGHT.get(
                priority,
                1.0,
            )
        )

        utility += (
            contribution
            * priority_weight
        )

        if (
            exercise.primary_muscle
            == muscle
        ):
            utility += (
                0.35
                * priority_weight
            )

    if exercise.is_compound:
        utility += 0.20

    return utility


def _marginal_set_seconds(
    item: FittedExercise,
) -> int:

    if item.sets <= 1:
        return (
            SET_EXECUTION_SECONDS
            + EXERCISE_TRANSITION_SECONDS
        )

    return (
        SET_EXECUTION_SECONDS
        + item.exercise.rest_seconds
    )


def _minimum_coverage(
    target: float,
) -> float:

    return min(
        target,
        MIN_EFFECTIVE_COVERAGE,
    )


def _simulate_trim(
    exercises: list[FittedExercise],
    index: int,
) -> list[FittedExercise]:

    simulated = list(
        exercises
    )

    item = simulated[index]

    if (
        item.sets
        <= MIN_SETS_PER_EXERCISE
    ):
        simulated.pop(
            index
        )

    else:
        simulated[index] = (
            FittedExercise(
                exercise=item.exercise,
                sets=item.sets - 1,
            )
        )

    return simulated


def _trim_preserves_coverage(
    session: SessionExercisePlan,
    exercises: list[FittedExercise],
    index: int,
) -> bool:

    simulated = _simulate_trim(
        exercises,
        index,
    )

    achieved, _ = (
        _recalculate_achievement(
            session,
            simulated,
        )
    )

    for (
        muscle,
        target,
    ) in session.target_effective_sets.items():

        minimum = _minimum_coverage(
            target
        )

        actual = achieved.get(
            muscle,
            0.0,
        )

        if actual + 1e-9 < minimum:
            return False

    return True


def _find_trim_candidate(
    context: GeneratorContext,
    session: SessionExercisePlan,
    exercises: list[
        FittedExercise
    ],
):
    candidates = []

    for index, item in enumerate(
        exercises
    ):
        if item.sets <= 0:
            continue

        if not _trim_preserves_coverage(
            session,
            exercises,
            index,
        ):
            continue

        utility = _exercise_utility(
            context,
            session,
            item,
        )

        seconds = (
            _marginal_set_seconds(
                item
            )
        )

        utility_per_second = (
            utility
            / max(
                seconds,
                1,
            )
        )

        # Prefer removing one-set fragments
        # first.
        fragment_penalty = (
            -1.0
            if item.sets == 1
            else 0.0
        )

        candidates.append(
            (
                fragment_penalty,
                utility_per_second,
                index,
            )
        )

    if not candidates:
        return None

    candidates.sort()

    return candidates[0][2]


def _trim_session(
    context: GeneratorContext,
    session: SessionExercisePlan,
) -> FittedSessionPlan:

    sport_factor = (
        training_capacity_factor(
            context,
            session.day_of_week,
        )
    )

    available_minutes = round(
        context.session_duration_minutes
        * sport_factor
    )

    available_seconds = (
        available_minutes
        * 60
    )

    exercises = [
        FittedExercise(
            exercise=item,
            sets=item.sets,
        )
        for item in session.exercises
    ]

    reasons = []

    if sport_factor < 1.0:
        reasons.append(
            "SAME_DAY_SPORT_ADJUSTMENT"
        )

    while (
        _session_seconds(
            exercises
        )
        > available_seconds
    ):
        trim_index = (
            _find_trim_candidate(
                context,
                session,
                exercises,
            )
        )

        if trim_index is None:
            raise DurationFitterError(
                f"Unable to fit session "
                f"{session.day_order} within "
                f"{available_minutes} minutes "
                f"without removing minimum "
                f"muscle coverage"
            )

        exercises = _simulate_trim(
            exercises,
            trim_index,
        )

        if (
            "SESSION_DURATION_LIMIT"
            not in reasons
        ):
            reasons.append(
                "SESSION_DURATION_LIMIT"
            )

    # Final cleanup:
    cleanup_index = 0

    while cleanup_index < len(
        exercises
    ):
        item = exercises[
            cleanup_index
        ]

        if (
            item.sets == 1
            and _trim_preserves_coverage(
                session,
                exercises,
                cleanup_index,
            )
        ):
            exercises.pop(
                cleanup_index
            )

        else:
            cleanup_index += 1

    achieved, remaining = (
        _recalculate_achievement(
            session,
            exercises,
        )
    )

    estimated_seconds = (
        _session_seconds(
            exercises
        )
    )

    return FittedSessionPlan(
        day_of_week=(
            session.day_of_week
        ),
        day_order=(
            session.day_order
        ),
        session_name=(
            session.session_name
        ),
        exercises=tuple(
            exercises
        ),
        physical_sets=sum(
            item.sets
            for item in exercises
        ),
        estimated_duration_minutes=round(
            estimated_seconds / 60
        ),
        available_duration_minutes=(
            available_minutes
        ),
        target_effective_sets=dict(
            session.target_effective_sets
        ),
        achieved_effective_sets=(
            achieved
        ),
        remaining_effective_sets=(
            remaining
        ),
        reason_codes=tuple(
            reasons
        ),
    )


def fit_session_to_constraints(
    context: GeneratorContext,
    session: SessionExercisePlan,
) -> FittedSessionPlan:

    return _trim_session(
        context,
        session,
    )


def fit_program_to_constraints(
    context: GeneratorContext,
    selection_plan: ExerciseSelectionPlan,
) -> FittedProgramPlan:

    sessions = tuple(
        fit_session_to_constraints(
            context,
            session,
        )
        for session
        in selection_plan.sessions
    )

    return FittedProgramPlan(
        sessions=sessions
    )