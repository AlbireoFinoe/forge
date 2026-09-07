from dataclasses import dataclass

from app.generator.builder import (
    ProgramBuildResult,
)
from app.generator.context import (
    GeneratorContext,
)


SOFT_MIN_RATIO = {
    "maintenance": 0.80,
    "normal": 0.85,
    "high": 0.90,
}

SOFT_MAX_RATIO = {
    "maintenance": 1.20,
    "normal": 1.25,
    "high": 1.25,
}

HARD_MIN_RATIO = 0.70
HARD_MAX_RATIO = 1.60

SESSION_REMAINING_TOLERANCE = 0.25

MIN_SESSION_PHYSICAL_SETS = 6

HIGH_SPORT_HEAVY_COMPOUND_SET_WARNING = 10


@dataclass(frozen=True)
class ValidationIssue:
    severity: str
    code: str
    message: str


@dataclass(frozen=True)
class MuscleVolumeResult:
    muscle_code: str
    priority: str

    target_effective_sets: float
    actual_effective_sets: float

    ratio: float


@dataclass(frozen=True)
class ProgramValidationReport:
    is_valid: bool

    muscle_volumes: tuple[
        MuscleVolumeResult,
        ...
    ]

    issues: tuple[
        ValidationIssue,
        ...
    ]


def _calculate_actual_weekly_volume(
    result: ProgramBuildResult,
) -> dict[str, float]:

    muscle_codes = set(
        result.volume_plan.targets
    )

    actual = {
        muscle_code: 0.0
        for muscle_code in muscle_codes
    }

    for session in (
        result.fitted_program.sessions
    ):
        for item in session.exercises:
            candidate = (
                item.exercise.exercise
            )

            for muscle_code in muscle_codes:
                contribution = (
                    candidate.contribution_for(
                        muscle_code
                    )
                )

                if contribution <= 0:
                    continue

                actual[
                    muscle_code
                ] += (
                    contribution
                    * item.sets
                )

    return {
        muscle: round(
            value,
            2,
        )
        for muscle, value
        in actual.items()
    }


def _validate_weekly_volume(
    context: GeneratorContext,
    result: ProgramBuildResult,
    issues: list[ValidationIssue],
) -> tuple[
    MuscleVolumeResult,
    ...
]:

    actual = (
        _calculate_actual_weekly_volume(
            result
        )
    )

    volume_results = []

    for (
        muscle_code,
        target,
    ) in sorted(
        result.volume_plan.targets.items()
    ):
        target_sets = float(
            target.target_effective_sets
        )

        actual_sets = actual.get(
            muscle_code,
            0.0,
        )

        ratio = (
            actual_sets / target_sets
            if target_sets > 0
            else 0.0
        )

        primary_candidate_count = (
            result.primary_candidate_counts.get(
                muscle_code,
                0,
            )
        )

        equipment_constrained = (
            "FULL_GYM"
            not in context.equipment_selection
        )

        equipment_limited = (
            equipment_constrained
            and primary_candidate_count == 0
        )

        priority = target.priority

        volume_results.append(
            MuscleVolumeResult(
                muscle_code=muscle_code,
                priority=priority,
                target_effective_sets=(
                    round(
                        target_sets,
                        2,
                    )
                ),
                actual_effective_sets=(
                    round(
                        actual_sets,
                        2,
                    )
                ),
                ratio=round(
                    ratio,
                    3,
                ),
            )
        )

        if ratio < HARD_MIN_RATIO:
            if equipment_limited:
                issues.append(
                    ValidationIssue(
                        severity="warning",
                        code=(
                            "EQUIPMENT_LIMITED_COVERAGE"
                        ),
                        message=(
                            f"{muscle_code}: no primary "
                            f"exercise is eligible with "
                            f"the current equipment; "
                            f"achieved "
                            f"{actual_sets:.2f}/"
                            f"{target_sets:.2f} "
                            f"effective sets "
                            f"({ratio:.0%})"
                        ),
                    )
                )
            else:
                issues.append(
                    ValidationIssue(
                        severity="error",
                        code=(
                            "WEEKLY_VOLUME_TOO_LOW"
                        ),
                        message=(
                            f"{muscle_code}: "
                            f"{actual_sets:.2f}/"
                            f"{target_sets:.2f} "
                            f"effective sets "
                            f"({ratio:.0%})"
                        ),
                    )
                )

            continue

        if ratio > HARD_MAX_RATIO:
            issues.append(
                ValidationIssue(
                    severity="error",
                    code="WEEKLY_VOLUME_TOO_HIGH",
                    message=(
                        f"{muscle_code}: "
                        f"{actual_sets:.2f}/"
                        f"{target_sets:.2f} "
                        f"effective sets "
                        f"({ratio:.0%})"
                    ),
                )
            )

            continue

        soft_min = (
            SOFT_MIN_RATIO.get(
                priority,
                0.85,
            )
        )

        soft_max = (
            SOFT_MAX_RATIO.get(
                priority,
                1.25,
            )
        )

        if ratio < soft_min:
            issues.append(
                ValidationIssue(
                    severity="warning",
                    code="WEEKLY_VOLUME_BELOW_TARGET",
                    message=(
                        f"{muscle_code}: "
                        f"{actual_sets:.2f}/"
                        f"{target_sets:.2f} "
                        f"effective sets "
                        f"({ratio:.0%})"
                    ),
                )
            )

        elif ratio > soft_max:
            issues.append(
                ValidationIssue(
                    severity="warning",
                    code="WEEKLY_VOLUME_ABOVE_TARGET",
                    message=(
                        f"{muscle_code}: "
                        f"{actual_sets:.2f}/"
                        f"{target_sets:.2f} "
                        f"effective sets "
                        f"({ratio:.0%})"
                    ),
                )
            )

    return tuple(
        volume_results
    )


def _validate_sessions(
    context: GeneratorContext,
    result: ProgramBuildResult,
    issues: list[ValidationIssue],
) -> None:

    for session in (
        result.fitted_program.sessions
    ):
        if (
            session.estimated_duration_minutes
            > session.available_duration_minutes
        ):
            issues.append(
                ValidationIssue(
                    severity="error",
                    code="SESSION_DURATION_EXCEEDED",
                    message=(
                        f"Day {session.day_order}: "
                        f"{session.estimated_duration_minutes}"
                        f"/"
                        f"{session.available_duration_minutes}"
                        f" min"
                    ),
                )
            )

        if session.physical_sets <= 0:
            issues.append(
                ValidationIssue(
                    severity="error",
                    code="EMPTY_SESSION",
                    message=(
                        f"Day {session.day_order} "
                        f"contains no working sets"
                    ),
                )
            )

        else:
            high_intensity_sport_today = any(
                sport.day_of_week
                == session.day_of_week
                and sport.intensity == "high"
                for sport in context.sports
            )

            sport_adjusted_micro_session = (
                high_intensity_sport_today
                and (
                    "SAME_DAY_SPORT_ADJUSTMENT"
                    in session.reason_codes
                )
            )

            if (
                session.physical_sets
                < MIN_SESSION_PHYSICAL_SETS
                and not sport_adjusted_micro_session
            ):
                issues.append(
                    ValidationIssue(
                        severity="warning",
                        code="LOW_SESSION_VOLUME",
                        message=(
                            f"Day {session.day_order}: "
                            f"only "
                            f"{session.physical_sets} "
                            f"physical sets"
                        ),
                    )
                )

        for (
            muscle,
            remaining,
        ) in (
            session
            .remaining_effective_sets
            .items()
        ):
            if (
                remaining
                > SESSION_REMAINING_TOLERANCE
            ):
                issues.append(
                    ValidationIssue(
                        severity="warning",
                        code=(
                            "SESSION_TARGET_NOT_FULLY_MET"
                        ),
                        message=(
                            f"Day "
                            f"{session.day_order} "
                            f"{muscle}: "
                            f"{remaining:.2f} "
                            f"effective sets "
                            f"remaining"
                        ),
                    )
                )

        one_set_exercises = [
            item
            for item in session.exercises
            if item.sets == 1
        ]

        if one_set_exercises:
            names = ", ".join(
                item.exercise.exercise.name
                for item in one_set_exercises
            )

            issues.append(
                ValidationIssue(
                    severity="warning",
                    code="ONE_SET_FRAGMENT",
                    message=(
                        f"Day {session.day_order}: "
                        f"{names}"
                    ),
                )
            )

        day_sports = [
            sport
            for sport in context.sports
            if sport.day_of_week
            == session.day_of_week
            and sport.intensity == "high"
        ]

        if day_sports:
            heavy_compound_sets = sum(
                item.sets
                for item in session.exercises
                if (
                    item.exercise
                    .exercise
                    .is_compound
                    and item.exercise
                    .rest_seconds
                    >= 150
                )
            )

            if (
                heavy_compound_sets
                > HIGH_SPORT_HEAVY_COMPOUND_SET_WARNING
            ):
                issues.append(
                    ValidationIssue(
                        severity="warning",
                        code=(
                            "HIGH_SPORT_HEAVY_COMPOUND_LOAD"
                        ),
                        message=(
                            f"Day "
                            f"{session.day_order}: "
                            f"{heavy_compound_sets} "
                            f"heavy compound sets "
                            f"with high-intensity "
                            f"sport on the same day"
                        ),
                    )
                )


def validate_program(
    context: GeneratorContext,
    result: ProgramBuildResult,
) -> ProgramValidationReport:

    issues: list[
        ValidationIssue
    ] = []

    muscle_volumes = (
        _validate_weekly_volume(
            context,
            result,
            issues,
        )
    )

    _validate_sessions(
        context,
        result,
        issues,
    )

    has_error = any(
        issue.severity == "error"
        for issue in issues
    )

    return ProgramValidationReport(
        is_valid=not has_error,
        muscle_volumes=(
            muscle_volumes
        ),
        issues=tuple(
            issues
        ),
    )