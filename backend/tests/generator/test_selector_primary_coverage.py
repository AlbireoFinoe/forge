from uuid import uuid4

import pytest

from app.generator.context import GeneratorContext
from app.generator.distribution import (
    SessionMuscleAllocation,
    VolumeDistributionPlan,
)
from app.generator.exercise_pool import (
    ExerciseCandidate,
    SecondaryMuscleContribution,
)
from app.generator.selector import (
    select_session_exercises,
)
from app.generator.split import ScheduledSession


def test_primary_coverage_rescue_reaches_valid_floor_when_score_turns_negative():
    """
    Regression for Case F.

    QUADS has a weekly target of 6 effective sets and
    Barbell Squat is the only eligible primary exercise.

    After three squat sets, collateral GLUTES overshoot
    makes the normal candidate score negative.

    The selector must not stop at 3/6 (50%), because that
    leaves QUADS below the generator's hard weekly volume
    floor. It should continue safely up to 5 sets, which
    gives 5/6 = 83.3% coverage without exceeding the
    per-exercise safety cap.
    """

    context = GeneratorContext(
        user_id=uuid4(),
        goal="muscle_gain",
        experience_level="intermediate",
        days_per_week=5,
        available_days=(1, 2, 3, 4, 5),
        session_duration_minutes=75,
        no_dedicated_leg_day=False,
        arm_specialization=False,
        muscle_priorities={
            "QUADS": "maintenance",
            "GLUTES": "maintenance",
            "HAMSTRINGS": "normal",
        },
        equipment_selection=(
            "BARBELL",
        ),
        available_equipment=frozenset(
            {
                "BARBELL",
                "BODYWEIGHT",
            }
        ),
        sports=(),
    )

    session = ScheduledSession(
        day_of_week=4,
        day_order=4,
        key="lower_body",
        name="Lower Body",
        focus_muscles=(
            "QUADS",
        ),
        sport_conflict_score=0.0,
        recovery_conflict_score=0.0,
        reason_codes=(),
    )

    distribution = VolumeDistributionPlan(
        allocations=(
            SessionMuscleAllocation(
                day_of_week=4,
                day_order=4,
                muscle_code="QUADS",
                target_effective_sets=6,
            ),
        )
    )

    squat = ExerciseCandidate(
        id=uuid4(),
        code="BARBELL_SQUAT",
        name="Barbell Squat",
        primary_muscle="QUADS",
        secondary_muscles=(
            SecondaryMuscleContribution(
                muscle_code="GLUTES",
                weight=0.60,
            ),
            SecondaryMuscleContribution(
                muscle_code="HAMSTRINGS",
                weight=0.25,
            ),
        ),
        movement_pattern="squat",
        difficulty="intermediate",
        is_compound=True,
        min_reps=5,
        max_reps=10,
        rest_seconds=180,
        required_equipment=frozenset(
            {
                "BARBELL",
            }
        ),
    )

    result = select_session_exercises(
        context=context,
        session=session,
        distribution=distribution,
        pool=(squat,),
        weekly_usage={},
        weekly_remaining={
            "QUADS": 6.0,
            "GLUTES": 0.6,
            "HAMSTRINGS": 1.0,
        },
        weekly_targets={
            "QUADS": 6.0,
            "GLUTES": 6.0,
            "HAMSTRINGS": 10.0,
        },
        weekly_actual={
            "QUADS": 0.0,
            "GLUTES": 5.4,
            "HAMSTRINGS": 9.0,
        },
    )

    assert result.physical_sets == 5

    assert (
        result.achieved_effective_sets[
            "QUADS"
        ]
        == 5.0
    )

    assert (
        result.remaining_effective_sets[
            "QUADS"
        ]
        == 1.0
    )

    assert len(result.exercises) == 1

    assert (
        result.exercises[0].exercise.code
        == "BARBELL_SQUAT"
    )

    assert result.exercises[0].sets == 5



@pytest.mark.parametrize(
    (
        "priority",
        "session_target",
        "weekly_target",
        "weekly_actual_before",
        "expected_sets",
    ),
    (
        (
            "maintenance",
            6.0,
            6.0,
            0.0,
            5,
        ),
        (
            "normal",
            5.0,
            10.0,
            3.0,
            4,
        ),
        (
            "high",
            5.0,
            14.0,
            6.0,
            4,
        ),
    ),
)
def test_primary_coverage_rescue_respects_minimum_floor_for_all_priorities(
    priority,
    session_target,
    weekly_target,
    weekly_actual_before,
    expected_sets,
):
    """
    Primary coverage rescue must not inherit a
    retention ratio that can leave an exposure
    below the generator's minimum valid floor.

    Collateral muscles are already at their weekly
    targets, so selecting the primary exercise has
    a negative normal score. The rescue path is
    therefore required.
    """

    context = GeneratorContext(
        user_id=uuid4(),
        goal="muscle_gain",
        experience_level="intermediate",
        days_per_week=5,
        available_days=(1, 2, 3, 4, 5),
        session_duration_minutes=75,
        no_dedicated_leg_day=False,
        arm_specialization=False,
        muscle_priorities={
            "QUADS": priority,
            "GLUTES": "maintenance",
            "HAMSTRINGS": "maintenance",
        },
        equipment_selection=(
            "BARBELL",
        ),
        available_equipment=frozenset(
            {
                "BARBELL",
                "BODYWEIGHT",
            }
        ),
        sports=(),
    )

    session = ScheduledSession(
        day_of_week=4,
        day_order=4,
        key="lower_body",
        name="Lower Body",
        focus_muscles=(
            "QUADS",
        ),
        sport_conflict_score=0.0,
        recovery_conflict_score=0.0,
        reason_codes=(),
    )

    distribution = VolumeDistributionPlan(
        allocations=(
            SessionMuscleAllocation(
                day_of_week=4,
                day_order=4,
                muscle_code="QUADS",
                target_effective_sets=(
                    session_target
                ),
            ),
        )
    )

    compound = ExerciseCandidate(
        id=uuid4(),
        code="TEST_QUAD_COMPOUND",
        name="Test Quad Compound",
        primary_muscle="QUADS",
        secondary_muscles=(
            SecondaryMuscleContribution(
                muscle_code="GLUTES",
                weight=0.80,
            ),
            SecondaryMuscleContribution(
                muscle_code="HAMSTRINGS",
                weight=0.50,
            ),
        ),
        movement_pattern="squat",
        difficulty="intermediate",
        is_compound=True,
        min_reps=5,
        max_reps=10,
        rest_seconds=180,
        required_equipment=frozenset(
            {
                "BARBELL",
            }
        ),
    )

    result = select_session_exercises(
        context=context,
        session=session,
        distribution=distribution,
        pool=(compound,),
        weekly_usage={},
        weekly_remaining={
            "QUADS": (
                weekly_target
                - weekly_actual_before
            ),
            "GLUTES": 0.0,
            "HAMSTRINGS": 0.0,
        },
        weekly_targets={
            "QUADS": weekly_target,
            "GLUTES": 6.0,
            "HAMSTRINGS": 6.0,
        },
        weekly_actual={
            "QUADS": weekly_actual_before,
            "GLUTES": 6.0,
            "HAMSTRINGS": 6.0,
        },
    )

    assert (
        result.physical_sets
        == expected_sets
    )

    assert (
        result.achieved_effective_sets[
            "QUADS"
        ]
        == float(expected_sets)
    )

    assert (
        "PRIMARY_COVERAGE_RESCUE"
        in result.exercises[
            0
        ].reason_codes
    )
