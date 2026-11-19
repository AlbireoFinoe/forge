from uuid import UUID

import pytest

from app.generator.context import GeneratorContext, SportContext
from app.generator.distribution import distribute_volume
from app.generator.split import ScheduledSession, SplitPlan, generate_split_plan
from app.generator.volume import MuscleVolumeTarget, VolumePlan, calculate_volume_plan


def _context(
    days: tuple[int, ...],
    priorities: dict[str, str],
    sports: tuple[SportContext, ...] = (),
) -> GeneratorContext:
    return GeneratorContext(
        user_id=UUID(int=1),
        goal="strength",
        experience_level="beginner",
        days_per_week=len(days),
        available_days=days,
        session_duration_minutes=15,
        no_dedicated_leg_day=False,
        arm_specialization=False,
        muscle_priorities=priorities,
        equipment_selection=("BODYWEIGHT",),
        available_equipment=frozenset({"BODYWEIGHT"}),
        sports=sports,
    )


def _chest_split(days: tuple[int, ...]) -> SplitPlan:
    sessions = tuple(
        ScheduledSession(
            day_of_week=day,
            day_order=order,
            key=f"CHEST_{order}",
            name=f"Chest {order}",
            focus_muscles=("CHEST",),
            sport_conflict_score=0.0,
            recovery_conflict_score=0.0,
            reason_codes=(),
        )
        for order, day in enumerate(days, start=1)
    )
    return SplitPlan(
        sessions=sessions,
        total_sport_conflict_score=0.0,
        total_recovery_conflict_score=0.0,
        total_score=0.0,
    )


def _chest_volume(priority: str, target: int) -> VolumePlan:
    return VolumePlan(
        targets={
            "CHEST": MuscleVolumeTarget(
                muscle_code="CHEST",
                priority=priority,
                base_sets=target,
                goal_adjusted_sets=target,
                specialization_bonus=0,
                target_effective_sets=target,
            ),
        },
    )


def test_short_beginner_strength_schedule_preserves_each_muscle_target():
    context = _context((1, 3, 5), {"CHEST": "high", "BACK": "normal"})
    volume = calculate_volume_plan(context)
    split = generate_split_plan(context)
    distribution = distribute_volume(context, volume, split)

    assert {muscle: target.target_effective_sets for muscle, target in volume.targets.items()} == {
        "CHEST": 1,
        "BACK": 1,
    }
    actual = {
        muscle: [item.target_effective_sets for item in distribution.allocations_for_muscle(muscle)]
        for muscle in volume.targets
    }
    assert actual == {"CHEST": [1], "BACK": [1]}
    assert all(item.day_of_week in context.available_days for item in distribution.allocations)


@pytest.mark.parametrize("days_per_week", range(1, 8))
@pytest.mark.parametrize("target", [1, 2, 3])
@pytest.mark.parametrize(
    ("priority", "desired_exposures"),
    [("maintenance", 1), ("normal", 2), ("high", 3)],
)
def test_small_target_is_conserved(
    days_per_week: int, target: int, priority: str, desired_exposures: int
):
    days = tuple(range(1, days_per_week + 1))
    context = _context(days, {"CHEST": priority})
    distribution = distribute_volume(context, _chest_volume(priority, target), _chest_split(days))
    allocations = distribution.allocations_for_muscle("CHEST")

    assert sum(item.target_effective_sets for item in allocations) == target
    assert len(allocations) == min(days_per_week, desired_exposures, target)
    assert len({item.day_of_week for item in allocations}) == len(allocations)
    assert all(item.day_of_week in days for item in allocations)
    assert all(1 <= item.target_effective_sets <= 6 for item in allocations)


@pytest.mark.parametrize(
    ("priority", "target", "expected"),
    [
        ("maintenance", 8, [4, 4]),
        ("normal", 10, [5, 5]),
        ("normal", 13, [5, 4, 4]),
        ("high", 16, [6, 5, 5]),
        ("high", 18, [6, 6, 6]),
    ],
)
def test_larger_targets_keep_their_distribution(
    priority: str, target: int, expected: list[int]
):
    days = (1, 3, 5)
    context = _context(days, {"CHEST": priority})
    distribution = distribute_volume(context, _chest_volume(priority, target), _chest_split(days))

    assert [
        item.target_effective_sets for item in distribution.allocations_for_muscle("CHEST")
    ] == expected


def test_single_set_keeps_capacity_based_day_selection():
    days = (1, 3, 5)
    context = _context(
        days,
        {"CHEST": "high"},
        (SportContext(sport_type="boxing", day_of_week=1, duration_minutes=60, intensity="high"),),
    )
    distribution = distribute_volume(context, _chest_volume("high", 1), _chest_split(days))

    assert [
        (item.day_of_week, item.target_effective_sets)
        for item in distribution.allocations_for_muscle("CHEST")
    ] == [(3, 1)]
