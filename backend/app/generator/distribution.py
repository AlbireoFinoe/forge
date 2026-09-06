from dataclasses import dataclass
from itertools import combinations
from math import ceil

from app.generator.context import GeneratorContext
from app.generator.fatigue import (
    training_capacity_factor,
)
from app.generator.split import SplitPlan
from app.generator.volume import VolumePlan


PRIORITY_EXPOSURES = {
    "maintenance": 1,
    "normal": 2,
    "high": 3,
}


PRIORITY_ORDER = {
    "high": 0,
    "normal": 1,
    "maintenance": 2,
}


MAX_EFFECTIVE_SETS_PER_EXPOSURE = {
    "maintenance": 6,
    "normal": 6,
    "high": 6,
}


MIN_EFFECTIVE_SETS_PER_EXPOSURE = 2


MUSCLE_FALLBACK_FOCUS = {
    "FRONT_DELTS": {
        "CHEST",
        "TRICEPS",
        "SIDE_DELTS",
    },

    "FOREARMS": {
        "BACK",
        "BICEPS",
    },

    "GLUTES": {
        "QUADS",
        "HAMSTRINGS",
    },

    "HAMSTRINGS": {
        "QUADS",
        "GLUTES",
    },

    "QUADS": {
        "HAMSTRINGS",
        "GLUTES",
    },

    "CALVES": {
        "QUADS",
        "HAMSTRINGS",
    },

    "ABS": {
        "QUADS",
        "HAMSTRINGS",
        "CALVES",
    },

    "TRAPS": {
        "BACK",
        "REAR_DELTS",
    },
}


@dataclass(frozen=True)
class SessionMuscleAllocation:
    day_of_week: int
    day_order: int

    muscle_code: str
    target_effective_sets: int


@dataclass(frozen=True)
class VolumeDistributionPlan:
    allocations: tuple[
        SessionMuscleAllocation,
        ...
    ]

    def allocations_for_muscle(
        self,
        muscle_code: str,
    ) -> tuple[
        SessionMuscleAllocation,
        ...
    ]:
        return tuple(
            allocation
            for allocation in self.allocations
            if allocation.muscle_code
            == muscle_code
        )


class VolumeDistributionError(Exception):
    pass


def _session_supports_muscle(
    muscle_code: str,
    focus_muscles: tuple[str, ...],
) -> bool:

    if muscle_code in focus_muscles:
        return True

    fallback = MUSCLE_FALLBACK_FOCUS.get(
        muscle_code,
        set(),
    )

    return bool(
        fallback.intersection(
            focus_muscles
        )
    )


def _selection_score(
    context: GeneratorContext,
    sessions,
    current_load: dict[int, int],
    estimated_sets: int,
    soft_session_target: float,
) -> float:

    score = 0.0

    for session in sessions:
        capacity = (
            training_capacity_factor(
                context,
                session.day_of_week,
            )
        )

        # Existing sport/recovery cost.
        score += (
            session.sport_conflict_score
            * 0.25
        )

        score += (
            session.recovery_conflict_score
            * 0.15
        )

        # Avoid repeatedly putting everything
        # on the same "easy" day.
        projected_load = (
            current_load[
                session.day_order
            ]
            + estimated_sets
        )

        score += projected_load * 0.20

        # Stronger soft penalty when one session
        # becomes substantially heavier than
        # the weekly average.
        capacity_target = (
            soft_session_target
            * capacity
        )

        overload_threshold = (
            capacity_target
            * 1.15
        )

        # Explicit penalty for placing volume
        # on a reduced-capacity day.
        score += (
            1.0 - capacity
        ) * 12.0

        if projected_load > overload_threshold:
            score += (
                projected_load
                - overload_threshold
            ) * 2.5

    # Prefer spacing exposures.
    ordered = sorted(
        sessions,
        key=lambda item: (
            item.day_of_week
        ),
    )

    for first, second in zip(
        ordered,
        ordered[1:],
    ):
        distance = (
            second.day_of_week
            - first.day_of_week
        )

        if distance == 1:
            score += 6.0

        elif distance == 2:
            score += 1.5

    return score


def _select_sessions(
    context: GeneratorContext,
    candidate_sessions,
    exposure_count: int,
    current_load: dict[int, int],
    total_sets: int,
    soft_session_target: float,
):
    if exposure_count >= len(
        candidate_sessions
    ):
        return tuple(
            candidate_sessions
        )

    estimated_sets = ceil(
        total_sets / exposure_count
    )

    best = None
    best_score = None

    for candidate in combinations(
        candidate_sessions,
        exposure_count,
    ):
        score = _selection_score(
            context=context,
            sessions=candidate,
            current_load=current_load,
            estimated_sets=estimated_sets,
            soft_session_target=(
                soft_session_target
            ),
        )

        if (
            best_score is None
            or score < best_score
        ):
            best = candidate
            best_score = score

    return best or ()


def _allocate_integer_sets(
    context: GeneratorContext,
    total_sets: int,
    sessions,
    current_load: dict[int, int],
    soft_session_target: float,
    priority: str,
) -> list[int]:

    count = len(sessions)

    if count == 0:
        return []

    max_per_exposure = (
        MAX_EFFECTIVE_SETS_PER_EXPOSURE[
            priority
        ]
    )

    if (
        total_sets
        > max_per_exposure * count
    ):
        raise VolumeDistributionError(
            f"Cannot distribute "
            f"{total_sets} sets across "
            f"{count} sessions for "
            f"priority {priority}"
        )

    allocations = [
        0
        for _ in sessions
    ]

    minimum = (
        MIN_EFFECTIVE_SETS_PER_EXPOSURE
        if total_sets >= count * 2
        else 1
    )

    # Every chosen exposure receives
    # meaningful minimum work first.
    for index in range(count):
        allocations[index] = minimum

    remaining = (
        total_sets
        - minimum * count
    )

    while remaining > 0:
        eligible = [
            index
            for index in range(count)
            if allocations[index]
            < max_per_exposure
        ]

        if not eligible:
            raise VolumeDistributionError(
                "Unable to distribute "
                "volume within exposure limits"
            )

        def allocation_score(
            index: int,
        ):
            session = sessions[index]

            capacity = (
                training_capacity_factor(
                    context,
                    session.day_of_week,
                )
            )

            effective_capacity = max(
                soft_session_target
                * capacity,
                1.0,
            )

            projected_load = (
                current_load[
                    session.day_order
                ]
                + allocations[index]
                + 1
            )

            load_ratio = (
                projected_load
                / effective_capacity
            )

            conflict_penalty = (
                session.sport_conflict_score
                * 0.015
                + session.recovery_conflict_score
                * 0.01
            )

            return (
                load_ratio
                + conflict_penalty
            )

        best_index = min(
            eligible,
            key=allocation_score,
        )

        allocations[
            best_index
        ] += 1

        remaining -= 1

    return allocations


def _determine_exposure_count(
    total_sets: int,
    priority: str,
    candidate_count: int,
) -> int:

    desired = PRIORITY_EXPOSURES.get(
        priority
    )

    if desired is None:
        raise VolumeDistributionError(
            f"Unsupported priority: "
            f"{priority}"
        )

    exposure_count = min(
        desired,
        candidate_count,
    )

    max_per_exposure = (
        MAX_EFFECTIVE_SETS_PER_EXPOSURE[
            priority
        ]
    )

    # If one exposure would become too large,
    # spread it further when suitable sessions
    # are available.
    while (
        exposure_count < candidate_count
        and ceil(
            total_sets / exposure_count
        ) > max_per_exposure
    ):
        exposure_count += 1

    return exposure_count


def distribute_volume(
    context: GeneratorContext,
    volume_plan: VolumePlan,
    split_plan: SplitPlan,
) -> VolumeDistributionPlan:

    allocations = []

    current_load = {
        session.day_order: 0
        for session in split_plan.sessions
    }

    total_effective_target = sum(
        target.target_effective_sets
        for target in volume_plan.targets.values()
    )

    soft_session_target = (
        total_effective_target
        / len(split_plan.sessions)
    )

    # High-priority muscles choose their
    # positions first.
    ordered_targets = sorted(
        volume_plan.targets.items(),
        key=lambda item: (
            PRIORITY_ORDER.get(
                item[1].priority,
                99,
            ),
            -item[
                1
            ].target_effective_sets,
            item[0],
        ),
    )

    for (
        muscle_code,
        volume_target,
    ) in ordered_targets:

        candidate_sessions = [
            session
            for session in split_plan.sessions
            if _session_supports_muscle(
                muscle_code,
                session.focus_muscles,
            )
        ]

        if not candidate_sessions:
            raise VolumeDistributionError(
                f"No suitable session found "
                f"for muscle {muscle_code}"
            )

        exposure_count = (
            _determine_exposure_count(
                total_sets=(
                    volume_target
                    .target_effective_sets
                ),
                priority=(
                    volume_target.priority
                ),
                candidate_count=len(
                    candidate_sessions
                ),
            )
        )

        selected_sessions = (
            _select_sessions(
                context=context,
                candidate_sessions=(
                    candidate_sessions
                ),
                exposure_count=(
                    exposure_count
                ),
                current_load=current_load,
                total_sets=(
                    volume_target
                    .target_effective_sets
                ),
                soft_session_target=(
                    soft_session_target
                ),
            )
        )

        set_distribution = (
            _allocate_integer_sets(
                context=context,
                total_sets=(
                    volume_target
                    .target_effective_sets
                ),
                sessions=(
                    selected_sessions
                ),
                current_load=(
                    current_load
                ),
                soft_session_target=(
                    soft_session_target
                ),
                priority=(
                    volume_target.priority
                ),
            )
        )

        for session, sets in zip(
            selected_sessions,
            set_distribution,
        ):
            allocations.append(
                SessionMuscleAllocation(
                    day_of_week=(
                        session.day_of_week
                    ),
                    day_order=(
                        session.day_order
                    ),
                    muscle_code=(
                        muscle_code
                    ),
                    target_effective_sets=(
                        sets
                    ),
                )
            )

            current_load[
                session.day_order
            ] += sets

    allocations.sort(
        key=lambda item: (
            item.day_order,
            item.muscle_code,
        )
    )

    return VolumeDistributionPlan(
        allocations=tuple(
            allocations
        )
    )