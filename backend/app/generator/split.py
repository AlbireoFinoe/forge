from dataclasses import dataclass
from itertools import permutations

from app.generator.context import (
    GeneratorContext,
    SportContext,
)


INTENSITY_WEIGHT = {
    "low": 1.0,
    "moderate": 2.0,
    "high": 3.0,
}


COMBAT_SPORTS = {
    "boxing",
    "muay_thai",
    "kickboxing",
    "mma",
    "martial_arts",
}


RUNNING_SPORTS = {
    "running",
    "jogging",
    "sprinting",
}


CYCLING_SPORTS = {
    "cycling",
    "bike",
    "biking",
}
PRIORITY_RECOVERY_WEIGHT = {
    "maintenance": 0.75,
    "normal": 1.0,
    "high": 1.35,
}


MUSCLE_RECOVERY_WEIGHT = {
    "CHEST": 1.2,
    "BACK": 1.2,
    "BICEPS": 1.0,
    "TRICEPS": 1.0,
    "FRONT_DELTS": 0.9,
    "SIDE_DELTS": 0.8,
    "REAR_DELTS": 0.8,
    "TRAPS": 0.8,
    "QUADS": 1.2,
    "HAMSTRINGS": 1.2,
    "GLUTES": 1.1,
    "CALVES": 0.5,
    "FOREARMS": 0.5,
    "ABS": 0.4,
}

@dataclass(frozen=True)
class SessionBlueprint:
    key: str
    name: str

    focus_muscles: tuple[str, ...]

    upper_load: int
    lower_load: int
    arm_load: int
    shoulder_load: int

    reason_codes: tuple[str, ...] = ()


@dataclass(frozen=True)
class ScheduledSession:
    day_of_week: int
    day_order: int

    key: str
    name: str

    focus_muscles: tuple[str, ...]

    sport_conflict_score: float
    recovery_conflict_score: float

    reason_codes: tuple[str, ...]


@dataclass(frozen=True)
class SplitPlan:
    sessions: tuple[ScheduledSession, ...]

    total_sport_conflict_score: float
    total_recovery_conflict_score: float
    total_score: float


class SplitEngineError(Exception):
    pass


def _session(
    key: str,
    name: str,
    focus: tuple[str, ...],
    upper: int,
    lower: int,
    arms: int,
    shoulders: int,
    reasons: tuple[str, ...] = (),
) -> SessionBlueprint:
    return SessionBlueprint(
        key=key,
        name=name,
        focus_muscles=focus,
        upper_load=upper,
        lower_load=lower,
        arm_load=arms,
        shoulder_load=shoulders,
        reason_codes=reasons,
    )


def _build_no_leg_day_split(
    days: int,
    arm_specialization: bool,
) -> list[SessionBlueprint]:

    if days == 1:
        return [
            _session(
                "FULL_BODY",
                "Full Body",
                (
                    "CHEST",
                    "BACK",
                    "SIDE_DELTS",
                    "BICEPS",
                    "TRICEPS",
                    "QUADS",
                    "HAMSTRINGS",
                ),
                upper=3,
                lower=2,
                arms=2,
                shoulders=2,
                reasons=(
                    "NO_DEDICATED_LEG_DAY",
                ),
            ),
        ]

    if days == 2:
        return [
            _session(
                "UPPER_A_QUADS",
                "Upper A + Quads",
                (
                    "CHEST",
                    "BACK",
                    "SIDE_DELTS",
                    "TRICEPS",
                    "QUADS",
                ),
                upper=3,
                lower=1,
                arms=1,
                shoulders=2,
                reasons=(
                    "NO_DEDICATED_LEG_DAY",
                ),
            ),
            _session(
                "UPPER_B_HAMSTRINGS",
                "Upper B + Hamstrings",
                (
                    "BACK",
                    "CHEST",
                    "BICEPS",
                    "REAR_DELTS",
                    "HAMSTRINGS",
                ),
                upper=3,
                lower=1,
                arms=1,
                shoulders=1,
                reasons=(
                    "NO_DEDICATED_LEG_DAY",
                ),
            ),
        ]

    if days == 3:
        third_name = (
            "Arms + Shoulders + Traps"
            if arm_specialization
            else "Upper Body + Accessories"
        )

        third_focus = (
            (
                "BICEPS",
                "TRICEPS",
                "SIDE_DELTS",
                "REAR_DELTS",
                "TRAPS",
            )
            if arm_specialization
            else (
                "CHEST",
                "BACK",
                "SIDE_DELTS",
                "TRAPS",
                "CALVES",
            )
        )

        return [
            _session(
                "PUSH_QUADS",
                "Push + Quads",
                (
                    "CHEST",
                    "SIDE_DELTS",
                    "TRICEPS",
                    "QUADS",
                ),
                3,
                1,
                2,
                2,
                ("NO_DEDICATED_LEG_DAY",),
            ),
            _session(
                "PULL_HAMSTRINGS",
                "Pull + Hamstrings",
                (
                    "BACK",
                    "BICEPS",
                    "REAR_DELTS",
                    "HAMSTRINGS",
                ),
                3,
                1,
                2,
                1,
                ("NO_DEDICATED_LEG_DAY",),
            ),
            _session(
                "SPECIALIZATION",
                third_name,
                third_focus,
                3,
                1,
                3 if arm_specialization else 1,
                3 if arm_specialization else 2,
                (
                    "ARM_SPECIALIZATION",
                    "NO_DEDICATED_LEG_DAY",
                )
                if arm_specialization
                else (
                    "NO_DEDICATED_LEG_DAY",
                ),
            ),
        ]

    if days == 4:
        return [
            _session(
                "PUSH_QUADS",
                "Chest + Delts + Triceps + Quads",
                (
                    "CHEST",
                    "SIDE_DELTS",
                    "TRICEPS",
                    "QUADS",
                ),
                3,
                1,
                2,
                2,
                ("NO_DEDICATED_LEG_DAY",),
            ),
            _session(
                "PULL_HAMSTRINGS",
                "Back + Biceps + Hamstrings",
                (
                    "BACK",
                    "BICEPS",
                    "REAR_DELTS",
                    "HAMSTRINGS",
                ),
                3,
                1,
                2,
                1,
                ("NO_DEDICATED_LEG_DAY",),
            ),
            _session(
                "UPPER_MIX",
                "Chest + Back + Calves",
                (
                    "CHEST",
                    "BACK",
                    "CALVES",
                ),
                3,
                1,
                1,
                1,
                ("NO_DEDICATED_LEG_DAY",),
            ),
            _session(
                "ARMS_SHOULDERS",
                (
                    "Arms + Shoulders + Traps"
                    if arm_specialization
                    else "Shoulders + Arms + Core"
                ),
                (
                    "BICEPS",
                    "TRICEPS",
                    "SIDE_DELTS",
                    "REAR_DELTS",
                    "TRAPS",
                    "ABS",
                ),
                3,
                0,
                3 if arm_specialization else 2,
                3,
                (
                    "ARM_SPECIALIZATION",
                    "NO_DEDICATED_LEG_DAY",
                )
                if arm_specialization
                else (
                    "NO_DEDICATED_LEG_DAY",
                ),
            ),
        ]

    base = [
        _session(
            "CHEST_DELTS_TRICEPS",
            "Chest + Delts + Triceps + Quads",
            (
                "CHEST",
                "SIDE_DELTS",
                "TRICEPS",
                "QUADS",
            ),
            3,
            1,
            2,
            2,
            ("NO_DEDICATED_LEG_DAY",),
        ),
        _session(
            "BACK_BICEPS_HAMSTRINGS",
            "Back + Biceps + Hamstrings",
            (
                "BACK",
                "BICEPS",
                "REAR_DELTS",
                "HAMSTRINGS",
            ),
            3,
            1,
            2,
            1,
            ("NO_DEDICATED_LEG_DAY",),
        ),
        _session(
            "ARMS_SHOULDERS_TRAPS",
            (
                "Arms + Shoulders + Traps"
                if arm_specialization
                else "Shoulders + Arms + Traps"
            ),
            (
                "BICEPS",
                "TRICEPS",
                "SIDE_DELTS",
                "REAR_DELTS",
                "TRAPS",
            ),
            3,
            0,
            3 if arm_specialization else 2,
            3,
            (
                "ARM_SPECIALIZATION",
                "NO_DEDICATED_LEG_DAY",
            )
            if arm_specialization
            else (
                "NO_DEDICATED_LEG_DAY",
            ),
        ),
        _session(
            "CHEST_BACK_QUADS",
            "Chest + Back + Quads",
            (
                "CHEST",
                "BACK",
                "QUADS",
            ),
            3,
            1,
            1,
            1,
            ("NO_DEDICATED_LEG_DAY",),
        ),
        _session(
            "BACK_ARMS_CALVES",
            "Back + Arms + Delts + Calves",
            (
                "BACK",
                "BICEPS",
                "TRICEPS",
                "SIDE_DELTS",
                "TRAPS",
                "CALVES",
            ),
            3,
            1,
            3 if arm_specialization else 2,
            2,
            (
                "ARM_SPECIALIZATION",
                "NO_DEDICATED_LEG_DAY",
            )
            if arm_specialization
            else (
                "NO_DEDICATED_LEG_DAY",
            ),
        ),
        _session(
            "UPPER_ACCESSORIES",
            "Upper Accessories + Hamstrings + Core",
            (
                "CHEST",
                "BACK",
                "REAR_DELTS",
                "HAMSTRINGS",
                "ABS",
            ),
            2,
            1,
            1,
            1,
            ("NO_DEDICATED_LEG_DAY",),
        ),
        _session(
            "LIGHT_ACCESSORIES",
            "Light Accessories + Core",
            (
                "SIDE_DELTS",
                "REAR_DELTS",
                "FOREARMS",
                "CALVES",
                "ABS",
            ),
            1,
            1,
            1,
            1,
            (
                "NO_DEDICATED_LEG_DAY",
                "RECOVERY_AWARE_SESSION",
            ),
        ),
    ]

    return base[:days]


def _build_standard_split(
    days: int,
    arm_specialization: bool,
) -> list[SessionBlueprint]:

    if days == 1:
        return [
            _session(
                "FULL_BODY",
                "Full Body",
                (
                    "CHEST",
                    "BACK",
                    "QUADS",
                    "HAMSTRINGS",
                    "SIDE_DELTS",
                    "BICEPS",
                    "TRICEPS",
                ),
                3,
                3,
                2,
                2,
            )
        ]

    if days == 2:
        return [
            _session(
                "FULL_BODY_A",
                "Full Body A",
                (
                    "CHEST",
                    "BACK",
                    "QUADS",
                    "SIDE_DELTS",
                    "TRICEPS",
                ),
                3,
                2,
                1,
                2,
            ),
            _session(
                "FULL_BODY_B",
                "Full Body B",
                (
                    "BACK",
                    "CHEST",
                    "HAMSTRINGS",
                    "BICEPS",
                    "REAR_DELTS",
                ),
                3,
                2,
                1,
                1,
            ),
        ]

    if days == 3:
        return [
            _session(
                "PUSH",
                "Push",
                (
                    "CHEST",
                    "FRONT_DELTS",
                    "SIDE_DELTS",
                    "TRICEPS",
                ),
                3,
                0,
                2,
                2,
            ),
            _session(
                "PULL",
                "Pull",
                (
                    "BACK",
                    "BICEPS",
                    "REAR_DELTS",
                    "TRAPS",
                ),
                3,
                0,
                2,
                1,
            ),
            _session(
                "LOWER",
                "Lower Body",
                (
                    "QUADS",
                    "HAMSTRINGS",
                    "GLUTES",
                    "CALVES",
                    "ABS",
                ),
                0,
                3,
                0,
                0,
            ),
        ]

    if days == 4:
        fourth = (
            _session(
                "ARMS_SHOULDERS",
                "Arms + Shoulders",
                (
                    "BICEPS",
                    "TRICEPS",
                    "SIDE_DELTS",
                    "REAR_DELTS",
                    "TRAPS",
                ),
                3,
                0,
                3,
                3,
                ("ARM_SPECIALIZATION",),
            )
            if arm_specialization
            else
            _session(
                "UPPER_B",
                "Upper B",
                (
                    "CHEST",
                    "BACK",
                    "SIDE_DELTS",
                    "BICEPS",
                    "TRICEPS",
                ),
                3,
                0,
                2,
                2,
            )
        )

        return [
            _session(
                "UPPER_A",
                "Upper A",
                (
                    "CHEST",
                    "BACK",
                    "SIDE_DELTS",
                    "BICEPS",
                    "TRICEPS",
                ),
                3,
                0,
                2,
                2,
            ),
            _session(
                "LOWER_A",
                "Lower A",
                (
                    "QUADS",
                    "HAMSTRINGS",
                    "GLUTES",
                    "CALVES",
                ),
                0,
                3,
                0,
                0,
            ),
            _session(
                "UPPER_PULL_PUSH",
                "Upper B",
                (
                    "BACK",
                    "CHEST",
                    "REAR_DELTS",
                    "TRAPS",
                ),
                3,
                0,
                1,
                1,
            ),
            fourth,
        ]

    base = [
        _session(
            "PUSH",
            "Push",
            (
                "CHEST",
                "FRONT_DELTS",
                "SIDE_DELTS",
                "TRICEPS",
            ),
            3,
            0,
            2,
            2,
        ),
        _session(
            "PULL",
            "Pull",
            (
                "BACK",
                "BICEPS",
                "REAR_DELTS",
                "TRAPS",
            ),
            3,
            0,
            2,
            1,
        ),
        _session(
            "LOWER",
            "Lower Body",
            (
                "QUADS",
                "HAMSTRINGS",
                "GLUTES",
                "CALVES",
            ),
            0,
            3,
            0,
            0,
        ),
        _session(
            "ARMS_SHOULDERS",
            (
                "Arms + Shoulders"
                if arm_specialization
                else "Upper Body"
            ),
            (
                "BICEPS",
                "TRICEPS",
                "SIDE_DELTS",
                "REAR_DELTS",
                "CHEST",
            ),
            3,
            0,
            3 if arm_specialization else 2,
            3 if arm_specialization else 2,
            (
                ("ARM_SPECIALIZATION",)
                if arm_specialization
                else ()
            ),
        ),
        _session(
            "UPPER_MIX",
            "Upper Mix",
            (
                "CHEST",
                "BACK",
                "TRAPS",
                "BICEPS",
                "TRICEPS",
            ),
            3,
            0,
            2,
            1,
        ),
        _session(
            "LOWER_B",
            "Lower B + Core",
            (
                "QUADS",
                "HAMSTRINGS",
                "GLUTES",
                "CALVES",
                "ABS",
            ),
            0,
            3,
            0,
            0,
        ),
        _session(
            "ACCESSORIES",
            "Accessories + Core",
            (
                "SIDE_DELTS",
                "REAR_DELTS",
                "BICEPS",
                "TRICEPS",
                "FOREARMS",
                "ABS",
            ),
            2,
            0,
            2,
            2,
            ("RECOVERY_AWARE_SESSION",),
        ),
    ]

    return base[:days]


def _build_blueprints(
    context: GeneratorContext,
) -> list[SessionBlueprint]:

    if context.days_per_week < 1:
        raise SplitEngineError(
            "days_per_week must be at least 1"
        )

    if context.days_per_week > 7:
        raise SplitEngineError(
            "days_per_week cannot exceed 7"
        )

    if context.no_dedicated_leg_day:
        return _build_no_leg_day_split(
            context.days_per_week,
            context.arm_specialization,
        )

    return _build_standard_split(
        context.days_per_week,
        context.arm_specialization,
    )


def _weekday_distance(
    day_a: int,
    day_b: int,
) -> int:
    raw = abs(day_a - day_b)

    return min(
        raw,
        7 - raw,
    )


def _sport_penalty(
    blueprint: SessionBlueprint,
    sport: SportContext,
    training_day: int,
) -> float:

    distance = _weekday_distance(
        training_day,
        sport.day_of_week,
    )

    if distance == 0:
        proximity = 1.0
    elif distance == 1:
        proximity = 0.45
    else:
        return 0.0

    intensity = INTENSITY_WEIGHT.get(
        sport.intensity,
        1.0,
    )

    sport_type = sport.sport_type.lower()

    if sport_type in COMBAT_SPORTS:
        workload = (
            blueprint.upper_load * 1.0
            + blueprint.arm_load * 1.4
            + blueprint.shoulder_load * 1.5
            + blueprint.lower_load * 0.4
        )

    elif sport_type in RUNNING_SPORTS:
        workload = (
            blueprint.lower_load * 2.0
            + blueprint.upper_load * 0.15
        )

    elif sport_type in CYCLING_SPORTS:
        workload = (
            blueprint.lower_load * 1.6
            + blueprint.upper_load * 0.1
        )

    else:
        workload = (
            blueprint.upper_load
            + blueprint.lower_load
        )

    duration_factor = max(
        0.5,
        min(
            sport.duration_minutes / 60,
            2.0,
        ),
    )

    return (
        workload
        * intensity
        * proximity
        * duration_factor
    )


def _score_session_on_day(
    context: GeneratorContext,
    blueprint: SessionBlueprint,
    training_day: int,
) -> float:

    return sum(
        _sport_penalty(
            blueprint,
            sport,
            training_day,
        )
        for sport in context.sports
    )


def _recovery_penalty_between_sessions(
    context: GeneratorContext,
    first: SessionBlueprint,
    second: SessionBlueprint,
    first_day: int,
    second_day: int,
) -> float:

    distance = _weekday_distance(
        first_day,
        second_day,
    )

    if distance == 1:
        proximity = 1.0

    elif distance == 2:
        proximity = 0.25

    else:
        return 0.0

    overlap = (
        set(first.focus_muscles)
        & set(second.focus_muscles)
    )

    penalty = 0.0

    for muscle in overlap:
        priority = context.muscle_priorities.get(
            muscle,
            "normal",
        )

        priority_weight = (
            PRIORITY_RECOVERY_WEIGHT.get(
                priority,
                1.0,
            )
        )

        muscle_weight = (
            MUSCLE_RECOVERY_WEIGHT.get(
                muscle,
                1.0,
            )
        )

        penalty += (
            muscle_weight
            * priority_weight
            * proximity
            * 4.0
        )

    return penalty


def _score_assignment_recovery(
    context: GeneratorContext,
    assignment: tuple[SessionBlueprint, ...],
    days: tuple[int, ...],
) -> float:

    score = 0.0

    for index in range(
        len(assignment) - 1
    ):
        score += (
            _recovery_penalty_between_sessions(
                context=context,
                first=assignment[index],
                second=assignment[index + 1],
                first_day=days[index],
                second_day=days[index + 1],
            )
        )

    return score


def generate_split_plan(
    context: GeneratorContext,
) -> SplitPlan:

    blueprints = _build_blueprints(
        context
    )

    days = tuple(
        sorted(context.available_days)
    )

    if len(blueprints) != len(days):
        raise SplitEngineError(
            "Split blueprint count does not match "
            "available training days"
        )

    best_assignment = None
    best_score = None

    for assignment in permutations(
        blueprints
    ):
        sport_score = 0.0

        for day, blueprint in zip(
            days,
            assignment,
        ):
            sport_score += (
                _score_session_on_day(
                    context,
                    blueprint,
                    day,
                )
            )

        recovery_score = (
            _score_assignment_recovery(
                context,
                assignment,
                days,
            )
        )

        score = (
            sport_score
            + recovery_score
        )

        if (
            best_score is None
            or score < best_score
        ):
            best_score = score
            best_assignment = assignment

    if best_assignment is None:
        raise SplitEngineError(
            "Unable to create training split"
        )

    total_recovery_score = (
        _score_assignment_recovery(
            context,
            best_assignment,
            days,
        )
    )

    sessions = []

    for index, (
        day,
        blueprint,
    ) in enumerate(
        zip(
            days,
            best_assignment,
        ),
        start=1,
    ):
        conflict_score = (
            _score_session_on_day(
                context,
                blueprint,
                day,
            )
        )

        reason_codes = list(
            blueprint.reason_codes
        )

        if conflict_score > 0:
            reason_codes.append(
                "SPORT_FATIGUE_ADJUSTMENT"
            )

        recovery_score = 0.0

        if index > 1:
            recovery_score += (
                _recovery_penalty_between_sessions(
                    context=context,
                    first=best_assignment[index - 2],
                    second=blueprint,
                    first_day=days[index - 2],
                    second_day=day,
                )
            )

        if recovery_score > 0:
            reason_codes.append(
                "RECOVERY_SPACING_ADJUSTMENT"
            )

        sessions.append(
            ScheduledSession(
                day_of_week=day,
                day_order=index,
                key=blueprint.key,
                name=blueprint.name,
                focus_muscles=(
                    blueprint.focus_muscles
                ),
                sport_conflict_score=round(
                    conflict_score,
                    2,
                ),
                recovery_conflict_score=round(
                    recovery_score,
                    2,
                ),
                reason_codes=tuple(
                    dict.fromkeys(
                        reason_codes
                    )
                ),
            )
        )

    total_sport_score = sum(
        session.sport_conflict_score
        for session in sessions
    )

    return SplitPlan(
        sessions=tuple(sessions),
        total_sport_conflict_score=round(
            total_sport_score,
            2,
        ),
        total_recovery_conflict_score=round(
            total_recovery_score,
            2,
        ),
        total_score=round(
            total_sport_score
            + total_recovery_score,
            2,
        ),
    )