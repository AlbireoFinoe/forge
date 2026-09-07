from dataclasses import dataclass
from itertools import combinations
from math import ceil

from app.generator.context import GeneratorContext
from app.generator.fatigue import (
    training_capacity_factor,
)
from app.generator.split import SplitPlan
from app.generator.volume import (
    MAX_EFFECTIVE_SETS_PER_MUSCLE_PER_DAY,
    VolumePlan,
)


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
    "maintenance": (
        MAX_EFFECTIVE_SETS_PER_MUSCLE_PER_DAY
    ),
    "normal": (
        MAX_EFFECTIVE_SETS_PER_MUSCLE_PER_DAY
    ),
    "high": (
        MAX_EFFECTIVE_SETS_PER_MUSCLE_PER_DAY
    ),
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


UPPER_BODY_MUSCLES = {
    "CHEST",
    "BACK",
    "BICEPS",
    "TRICEPS",
    "FOREARMS",
    "FRONT_DELTS",
    "SIDE_DELTS",
    "REAR_DELTS",
    "TRAPS",
}


LOWER_BODY_MUSCLES = {
    "QUADS",
    "HAMSTRINGS",
    "GLUTES",
    "CALVES",
}


def _session_is_same_region(
    muscle_code: str,
    focus_muscles: tuple[str, ...],
) -> bool:

    focus = set(
        focus_muscles
    )

    if muscle_code in UPPER_BODY_MUSCLES:
        return bool(
            focus
            & UPPER_BODY_MUSCLES
        )

    if muscle_code in LOWER_BODY_MUSCLES:
        return bool(
            focus
            & LOWER_BODY_MUSCLES
        )

    if muscle_code == "ABS":
        # Core work can reasonably be placed
        # at the end of almost any session.
        return True

    return False


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


def _single_exposure_score(
    context: GeneratorContext,
    session,
    muscle_code: str,
    total_sets: int,
    current_load: dict[int, int],
    soft_session_target: float,
):
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
        + total_sets
    )

    projected_load_ratio = (
        projected_load
        / effective_capacity
    )

    # A session where this muscle is
    # explicitly part of the blueprint
    # should beat a fallback placement
    # unless constraints strongly argue
    # otherwise.
    fallback_penalty = (
        0
        if muscle_code
        in session.focus_muscles
        else 1
    )

    reduced_capacity_penalty = (
        1
        if capacity < 0.85
        else 0
    )

    overload_penalty = max(
        0.0,
        projected_load_ratio - 1.15,
    )

    return (
        reduced_capacity_penalty,
        fallback_penalty,
        overload_penalty,
        projected_load_ratio,
        -capacity,
        session.sport_conflict_score,
        session.recovery_conflict_score,
        session.day_order,
    )


def _select_sessions(
    context: GeneratorContext,
    muscle_code: str,
    candidate_sessions,
    exposure_count: int,
    current_load: dict[int, int],
    total_sets: int,
    soft_session_target: float,
):
    if (
        exposure_count == 1
        and len(candidate_sessions) > 1
    ):
        best_session = min(
            candidate_sessions,
            key=lambda session: (
                _single_exposure_score(
                    context=context,
                    session=session,
                    muscle_code=muscle_code,
                    total_sets=total_sets,
                    current_load=current_load,
                    soft_session_target=(
                        soft_session_target
                    ),
                )
            ),
        )

        return [
            best_session
        ]

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

        all_sessions = list(
            split_plan.sessions
        )

        direct_sessions = [
            session
            for session in all_sessions
            if _session_supports_muscle(
                muscle_code,
                session.focus_muscles,
            )
        ]

        # Exposure requirement is calculated
        # against the complete gym schedule,
        # not only the original split labels.
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
                    all_sessions
                ),
            )
        )

        if len(
            direct_sessions
        ) >= exposure_count:

            selected_sessions = (
                _select_sessions(
                    context=context,
                    muscle_code=(
                        volume_target
                        .muscle_code
                    ),
                    candidate_sessions=(
                        direct_sessions
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

        else:
            # Keep all direct / fallback
            # exposures first.
            selected_sessions = list(
                direct_sessions
            )

            needed = (
                exposure_count
                - len(selected_sessions)
            )

            # Tier 2:
            # expand inside the same body region.
            same_region_sessions = [
                session
                for session in all_sessions
                if (
                    session
                    not in selected_sessions
                    and _session_is_same_region(
                        muscle_code,
                        session.focus_muscles,
                    )
                )
            ]

            if (
                needed > 0
                and same_region_sessions
            ):
                take = min(
                    needed,
                    len(
                        same_region_sessions
                    ),
                )

                chosen = (
                    _select_sessions(
                        context=context,
                        muscle_code=(
                            volume_target
                            .muscle_code
                        ),
                        candidate_sessions=(
                            same_region_sessions
                        ),
                        exposure_count=take,
                        current_load=(
                            current_load
                        ),
                        total_sets=(
                            volume_target
                            .target_effective_sets
                        ),
                        soft_session_target=(
                            soft_session_target
                        ),
                    )
                )

                selected_sessions.extend(
                    chosen
                )

                needed -= len(
                    chosen
                )

            # Tier 3:
            # last-resort schedule expansion.
            #
            # This allows, for example, a few
            # biceps sets at the end of another
            # session when a 3-day schedule needs
            # three exposures to make the weekly
            # target feasible.
            if needed > 0:
                remaining_sessions = [
                    session
                    for session in all_sessions
                    if session
                    not in selected_sessions
                ]

                if len(
                    remaining_sessions
                ) < needed:
                    raise VolumeDistributionError(
                        f"Not enough training "
                        f"sessions to create "
                        f"{exposure_count} exposures "
                        f"for {muscle_code}"
                    )

                chosen = (
                    _select_sessions(
                        context=context,
                        muscle_code=(
                            volume_target
                            .muscle_code
                        ),
                        candidate_sessions=(
                            remaining_sessions
                        ),
                        exposure_count=needed,
                        current_load=(
                            current_load
                        ),
                        total_sets=(
                            volume_target
                            .target_effective_sets
                        ),
                        soft_session_target=(
                            soft_session_target
                        ),
                    )
                )

                selected_sessions.extend(
                    chosen
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