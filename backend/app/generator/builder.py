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

    weekly_remaining = {
        muscle_code: float(
            target.target_effective_sets
        )
        for muscle_code, target
        in volume_plan.targets.items()
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
    )