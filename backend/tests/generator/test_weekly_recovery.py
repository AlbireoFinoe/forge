from uuid import UUID

import pytest

from app.generator import split
from app.generator.context import GeneratorContext
from app.generator.distribution import _selection_score, distribute_volume
from app.generator.split import ScheduledSession, SessionBlueprint, SplitPlan
from app.generator.volume import MuscleVolumeTarget, VolumePlan


def _context(days: tuple[int, ...]) -> GeneratorContext:
    return GeneratorContext(
        user_id=UUID(int=1),
        goal="strength",
        experience_level="beginner",
        days_per_week=len(days),
        available_days=days,
        session_duration_minutes=60,
        no_dedicated_leg_day=False,
        arm_specialization=False,
        muscle_priorities={"CHEST": "high"},
        equipment_selection=("BODYWEIGHT",),
        available_equipment=frozenset({"BODYWEIGHT"}),
        sports=(),
    )


def _fixed_blueprints(monkeypatch, muscles: tuple[str, ...]) -> None:
    blueprints = [
        SessionBlueprint(
            key=f"session_{index}",
            name=f"Session {index}",
            focus_muscles=(muscle,),
            upper_load=1,
            lower_load=0,
            arm_load=0,
            shoulder_load=0,
        )
        for index, muscle in enumerate(muscles, start=1)
    ]
    monkeypatch.setattr(split, "_build_blueprints", lambda _context: blueprints)


@pytest.mark.parametrize(
    ("days", "expected_by_day"),
    [
        ((1, 3, 7), {1: 6.48, 3: 1.62, 7: 0.0}),
        ((1, 2, 3), {1: 0.0, 2: 6.48, 3: 8.10}),
        ((1, 7), {1: 6.48, 7: 0.0}),
        ((2, 7), {2: 1.62, 7: 0.0}),
        ((1, 3), {1: 0.0, 3: 1.62}),
        ((1, 4), {1: 0.0, 4: 0.0}),
        ((7,), {7: 0.0}),
    ],
    ids=[
        "monday-wednesday-sunday",
        "two-day-gap-with-intervening-session",
        "two-sessions-across-boundary",
        "two-day-gap-across-boundary",
        "two-sessions-within-week",
        "three-day-gap",
        "one-session",
    ],
)
def test_split_recovery_counts_each_pair_once(monkeypatch, days, expected_by_day):
    _fixed_blueprints(monkeypatch, ("CHEST",) * len(days))

    plan = split.generate_split_plan(_context(days))

    assert plan.total_recovery_conflict_score == pytest.approx(sum(expected_by_day.values()))
    assert plan.total_score == plan.total_recovery_conflict_score
    for session in plan.sessions:
        expected = expected_by_day[session.day_of_week]
        assert session.recovery_conflict_score == expected
        assert ("RECOVERY_SPACING_ADJUSTMENT" in session.reason_codes) == (expected > 0)
    assert split.generate_split_plan(_context(days[::-1])) == plan


def test_split_without_overlapping_muscles_has_no_recovery_penalty(monkeypatch):
    _fixed_blueprints(monkeypatch, ("CHEST", "BACK", "QUADS"))

    plan = split.generate_split_plan(_context((1, 2, 7)))

    assert plan.total_recovery_conflict_score == 0
    assert all(session.recovery_conflict_score == 0 for session in plan.sessions)
    assert all("RECOVERY_SPACING_ADJUSTMENT" not in session.reason_codes for session in plan.sessions)


def test_split_ranking_avoids_overlap_across_week_boundary(monkeypatch):
    _fixed_blueprints(monkeypatch, ("CHEST", "CHEST", "BACK"))

    plan = split.generate_split_plan(_context((1, 3, 7)))

    assert plan.total_recovery_conflict_score == 0
    assert [session.day_of_week for session in plan.sessions if "CHEST" in session.focus_muscles] == [3, 7]


def _chest_sessions(days: tuple[int, ...]) -> tuple[ScheduledSession, ...]:
    return tuple(
        ScheduledSession(
            day_of_week=day,
            day_order=order,
            key=f"session_{order}",
            name=f"Session {order}",
            focus_muscles=("CHEST",),
            sport_conflict_score=0.0,
            recovery_conflict_score=0.0,
            reason_codes=(),
        )
        for order, day in enumerate(days, start=1)
    )


@pytest.mark.parametrize(
    ("days", "expected"),
    [
        ((1, 3, 7), 7.5),
        ((1, 2, 3), 13.5),
        ((1, 7), 6.0),
        ((2, 7), 1.5),
        ((1, 3), 1.5),
        ((1, 4), 0.0),
        ((7,), 0.0),
    ],
)
def test_exposure_spacing_counts_each_pair_once_in_any_order(days, expected):
    sessions = _chest_sessions(days)
    context = _context(days)
    load = {session.day_order: 0 for session in sessions}

    assert _selection_score(context, sessions, load, 0, 1.0) == expected
    assert _selection_score(context, sessions[::-1], load, 0, 1.0) == expected


def test_distribution_chooses_exposures_with_weekly_spacing():
    days = (1, 3, 7)
    context = _context(days)
    plan = SplitPlan(
        sessions=_chest_sessions(days),
        total_sport_conflict_score=0.0,
        total_recovery_conflict_score=0.0,
        total_score=0.0,
    )
    volume = VolumePlan(
        targets={
            "CHEST": MuscleVolumeTarget(
                muscle_code="CHEST",
                priority="normal",
                base_sets=4,
                goal_adjusted_sets=4,
                specialization_bonus=0,
                target_effective_sets=4,
            )
        }
    )

    result = distribute_volume(context, volume, plan)

    assert [
        (allocation.day_of_week, allocation.target_effective_sets)
        for allocation in result.allocations_for_muscle("CHEST")
    ] == [(3, 2), (7, 2)]
