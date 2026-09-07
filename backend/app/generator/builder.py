from dataclasses import dataclass

from sqlalchemy.orm import Session

from app.generator.context import (
    GeneratorContext,
)
from app.generator.distribution import (
    VolumeDistributionPlan,
    distribute_volume,
)
from app.generator.exercise_pool import (
    load_exercise_pool,
)
from app.generator.fitter import (
    FittedProgramPlan,
    FittedSessionPlan,
    fit_session_to_constraints,
)
from app.generator.selector import (
    ExerciseSelectionPlan,
    SPILLOVER_CREDIT_FACTOR,
    SessionExercisePlan,
    select_session_exercises,
)
from app.generator.split import (
    SplitPlan,
    generate_split_plan,
)
from app.generator.volume import (
    VolumePlan,
    calculate_volume_plan,
)


@dataclass(frozen=True)
class ProgramBuildResult:
    volume_plan: VolumePlan

    split_plan: SplitPlan

    distribution_plan: (
        VolumeDistributionPlan
    )

    selection_plan: (
        ExerciseSelectionPlan
    )

    fitted_program: (
        FittedProgramPlan
    )

    planning_remaining_effective_sets: (
        dict[str, float]
    )

    planning_actual_effective_sets: (
        dict[str, float]
    )

    primary_candidate_counts: (
        dict[str, int]
    )


def _apply_fitted_weekly_credit(
    session: FittedSessionPlan,
    weekly_remaining: dict[str, float],
) -> None:

    target_muscles = set(
        session.target_effective_sets
    )

    for item in session.exercises:
        candidate = (
            item.exercise.exercise
        )

        for muscle_code in (
            weekly_remaining
        ):
            contribution = (
                candidate.contribution_for(
                    muscle_code
                )
                * item.sets
            )

            if contribution <= 0:
                continue

            if (
                muscle_code
                not in target_muscles
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


def _apply_fitted_actual(
    session: FittedSessionPlan,
    weekly_actual: dict[str, float],
) -> None:

    for item in session.exercises:
        candidate = (
            item.exercise.exercise
        )

        for muscle_code in (
            weekly_actual
        ):
            contribution = (
                candidate.contribution_for(
                    muscle_code
                )
                * item.sets
            )

            if contribution <= 0:
                continue

            weekly_actual[
                muscle_code
            ] += contribution


def _apply_fitted_usage(
    session: FittedSessionPlan,
    weekly_usage: dict[str, int],
) -> None:

    for item in session.exercises:
        code = (
            item.exercise
            .exercise
            .code
        )

        weekly_usage[code] = (
            weekly_usage.get(
                code,
                0,
            )
            + 1
        )


def build_program_plan(
    db: Session,
    context: GeneratorContext,
) -> ProgramBuildResult:

    volume_plan = (
        calculate_volume_plan(
            context
        )
    )

    split_plan = (
        generate_split_plan(
            context
        )
    )

    distribution_plan = (
        distribute_volume(
            context,
            volume_plan,
            split_plan,
        )
    )

    pool = load_exercise_pool(
        db,
        context,
    )

    weekly_targets = {
        muscle_code: float(
            target.target_effective_sets
        )
        for muscle_code, target
        in volume_plan.targets.items()
    }

    primary_candidate_counts = {
        muscle_code: sum(
            1
            for exercise in pool
            if exercise.primary_muscle
            == muscle_code
        )
        for muscle_code
        in weekly_targets
    }

    weekly_remaining = dict(
        weekly_targets
    )

    weekly_actual = {
        muscle_code: 0.0
        for muscle_code
        in weekly_targets
    }

    weekly_usage: dict[
        str,
        int,
    ] = {}

    selected_sessions: list[
        SessionExercisePlan
    ] = []

    fitted_sessions: list[
        FittedSessionPlan
    ] = []

    for session in (
        split_plan.sessions
    ):
        selected = (
            select_session_exercises(
                context=context,
                session=session,
                distribution=(
                    distribution_plan
                ),
                pool=pool,
                weekly_usage=(
                    weekly_usage
                ),
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

        selected_sessions.append(
            selected
        )

        fitted = (
            fit_session_to_constraints(
                context,
                selected,
            )
        )

        fitted_sessions.append(
            fitted
        )

        # IMPORTANT:
        # only the FINAL fitted work gets
        # credited toward future days.
        _apply_fitted_weekly_credit(
            fitted,
            weekly_remaining,
        )

        _apply_fitted_actual(
            fitted,
            weekly_actual,
        )

        _apply_fitted_usage(
            fitted,
            weekly_usage,
        )

    return ProgramBuildResult(
        volume_plan=volume_plan,
        split_plan=split_plan,
        distribution_plan=(
            distribution_plan
        ),
        selection_plan=(
            ExerciseSelectionPlan(
                sessions=tuple(
                    selected_sessions
                )
            )
        ),
        fitted_program=(
            FittedProgramPlan(
                sessions=tuple(
                    fitted_sessions
                )
            )
        ),
        planning_remaining_effective_sets={
            muscle: round(
                remaining,
                2,
            )
            for muscle, remaining
            in weekly_remaining.items()
        },
        planning_actual_effective_sets={
            muscle: round(
                actual,
                2,
            )
            for muscle, actual
            in weekly_actual.items()
        },
        primary_candidate_counts=(
            primary_candidate_counts
        ),
    )