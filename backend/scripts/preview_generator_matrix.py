import argparse
from dataclasses import replace

from sqlalchemy import select

from app.core.database import SessionLocal
from app.generator.builder import build_program_plan
from app.generator.context import (
    GeneratorContext,
    SportContext,
    build_generator_context,
)
from app.generator.validator import validate_program
from app.models.user import User


DAY_NAMES = {
    1: "Mon",
    2: "Tue",
    3: "Wed",
    4: "Thu",
    5: "Fri",
    6: "Sat",
    7: "Sun",
}


def format_days(days):
    return ", ".join(
        DAY_NAMES[day]
        for day in days
    )


def make_priorities(
    base: GeneratorContext,
    high: tuple[str, ...] = (),
    maintenance: tuple[str, ...] = (),
) -> dict[str, str]:

    priorities = {
        muscle_code: "normal"
        for muscle_code
        in base.muscle_priorities
    }

    for muscle_code in maintenance:
        if muscle_code in priorities:
            priorities[
                muscle_code
            ] = "maintenance"

    for muscle_code in high:
        if muscle_code in priorities:
            priorities[
                muscle_code
            ] = "high"

    return priorities


def make_context(
    base: GeneratorContext,
    gym_days: tuple[int, ...],
    sports: tuple[SportContext, ...] = (),
    muscle_priorities: dict[str, str] | None = None,
    arm_specialization: bool | None = None,
    equipment_selection: tuple[str, ...] | None = None,
    available_equipment: frozenset[str] | None = None,
) -> GeneratorContext:

    return replace(
        base,
        days_per_week=len(gym_days),
        available_days=gym_days,
        sports=sports,
        muscle_priorities=(
            muscle_priorities
            if muscle_priorities is not None
            else base.muscle_priorities
        ),
        arm_specialization=(
            arm_specialization
            if arm_specialization is not None
            else base.arm_specialization
        ),
        equipment_selection=(
            equipment_selection
            if equipment_selection is not None
            else base.equipment_selection
        ),
        available_equipment=(
            available_equipment
            if available_equipment is not None
            else base.available_equipment
        ),
    )


def run_case(
    db,
    name: str,
    context: GeneratorContext,
):
    print()
    print("=" * 90)
    print(name)
    print("=" * 90)

    print(
        "Expected gym days:",
        format_days(
            context.available_days
        ),
    )

    print(
        "Available equipment:",
        ", ".join(
            sorted(
                context.available_equipment
            )
        ),
    )

    if context.sports:
        print("Sports:")

        for sport in context.sports:
            print(
                "  "
                f"{DAY_NAMES[sport.day_of_week]} "
                f"{sport.sport_type} "
                f"{sport.duration_minutes}min "
                f"{sport.intensity}"
            )
    else:
        print("Sports: none")

    try:
        result = build_program_plan(
            db,
            context,
        )

        report = validate_program(
            context,
            result,
        )

    except Exception as exc:
        print()
        print("BUILD: FAIL")
        print(
            f"{type(exc).__name__}: "
            f"{exc}"
        )

        return False

    sessions = (
        result
        .fitted_program
        .sessions
    )

    generated_days = tuple(
        session.day_of_week
        for session in sessions
    )

    expected_days = tuple(
        context.available_days
    )

    unexpected_days = sorted(
        set(generated_days)
        - set(expected_days)
    )

    missing_days = sorted(
        set(expected_days)
        - set(generated_days)
    )

    print()
    print("BUILD: PASS")

    print(
        "VALIDATION:",
        report.is_valid,
    )

    print(
        "Generated gym days:",
        format_days(
            generated_days
        ),
    )

    if unexpected_days:
        print(
            "Unexpected days:",
            format_days(
                unexpected_days
            ),
        )
    else:
        print(
            "Unexpected days: none"
        )

    if missing_days:
        print(
            "Missing days:",
            format_days(
                missing_days
            ),
        )
    else:
        print(
            "Missing days: none"
        )

    print()
    print("Sessions")
    print("-" * 90)

    for session in sessions:
        print(
            f"{DAY_NAMES[session.day_of_week]:3} | "
            f"{session.session_name:35} | "
            f"{session.estimated_duration_minutes:3} min | "
            f"{len(session.exercises):2} exercises | "
            f"{sum(item.sets for item in session.exercises):2} sets"
        )

    print()
    print("Planning actual effective sets")
    print("-" * 90)

    for muscle_code, actual in sorted(
        result
        .planning_actual_effective_sets
        .items()
    ):
        print(
            f"{muscle_code:15} "
            f"actual={actual:.2f}"
        )

    warnings = [
        issue
        for issue in report.issues
        if issue.severity == "warning"
    ]

    errors = [
        issue
        for issue in report.issues
        if issue.severity == "error"
    ]

    print()
    print(
        f"Warnings: {len(warnings)}"
    )

    for issue in warnings:
        print(
            f"  [{issue.code}] "
            f"{issue.message}"
        )

    print(
        f"Errors: {len(errors)}"
    )

    for issue in errors:
        print(
            f"  [{issue.code}] "
            f"{issue.message}"
        )

    day_match = (
        generated_days
        == expected_days
    )

    passed = (
        report.is_valid
        and day_match
        and not unexpected_days
        and not missing_days
    )

    print()
    print(
        "CASE RESULT:",
        "PASS" if passed else "FAIL",
    )

    return passed


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--email",
        required=True,
    )

    args = parser.parse_args()

    db = SessionLocal()

    try:
        user = db.scalar(
            select(User).where(
                User.email
                == args.email.lower()
            )
        )

        if user is None:
            print("User not found.")
            return

        base_context = (
            build_generator_context(
                db,
                user,
            )
        )

        cases = [
            (
                "CASE A - 3x non-consecutive, no sports",
                make_context(
                    base_context,
                    gym_days=(
                        1,
                        3,
                        5,
                    ),
                ),
            ),

            (
                "CASE B - 4x non-consecutive + futsal/swimming",
                make_context(
                    base_context,
                    gym_days=(
                        1,
                        3,
                        5,
                        7,
                    ),
                    sports=(
                        SportContext(
                            sport_type="futsal",
                            day_of_week=2,
                            duration_minutes=90,
                            intensity="high",
                        ),
                        SportContext(
                            sport_type="swimming",
                            day_of_week=6,
                            duration_minutes=45,
                            intensity="moderate",
                        ),
                    ),
                ),
            ),

            (
                "CASE C - 5x irregular + basketball",
                make_context(
                    base_context,
                    gym_days=(
                        1,
                        2,
                        4,
                        5,
                        7,
                    ),
                    sports=(
                        SportContext(
                            sport_type="basketball",
                            day_of_week=3,
                            duration_minutes=90,
                            intensity="high",
                        ),
                    ),
                ),
            ),

            (
                "CASE D - 2x gym + cycling",
                make_context(
                    base_context,
                    gym_days=(
                        2,
                        6,
                    ),
                    sports=(
                        SportContext(
                            sport_type="cycling",
                            day_of_week=1,
                            duration_minutes=45,
                            intensity="moderate",
                        ),
                        SportContext(
                            sport_type="cycling",
                            day_of_week=3,
                            duration_minutes=45,
                            intensity="moderate",
                        ),
                        SportContext(
                            sport_type="cycling",
                            day_of_week=5,
                            duration_minutes=60,
                            intensity="moderate",
                        ),
                    ),
                ),
            ),

            (
                "CASE E - 6x gym + multiple sports",
                make_context(
                    base_context,
                    gym_days=(
                        1,
                        2,
                        3,
                        4,
                        5,
                        6,
                    ),
                    sports=(
                        SportContext(
                            sport_type="badminton",
                            day_of_week=2,
                            duration_minutes=60,
                            intensity="moderate",
                        ),
                        SportContext(
                            sport_type="martial_arts",
                            day_of_week=4,
                            duration_minutes=75,
                            intensity="high",
                        ),
                        SportContext(
                            sport_type="swimming",
                            day_of_week=7,
                            duration_minutes=45,
                            intensity="low",
                        ),
                    ),
                ),
            ),

            (
                "CASE F - 5x gym + chest focus",
                make_context(
                    base_context,
                    gym_days=(
                        1,
                        2,
                        3,
                        4,
                        5,
                    ),
                    muscle_priorities=(
                        make_priorities(
                            base_context,
                            high=(
                                "CHEST",
                            ),
                            maintenance=(
                                "QUADS",
                                "GLUTES",
                            ),
                        )
                    ),
                    arm_specialization=False,
                ),
            ),

            (
                "CASE G - 4x gym + back focus",
                make_context(
                    base_context,
                    gym_days=(
                        1,
                        2,
                        4,
                        6,
                    ),
                    muscle_priorities=(
                        make_priorities(
                            base_context,
                            high=(
                                "BACK",
                            ),
                            maintenance=(
                                "QUADS",
                                "GLUTES",
                            ),
                        )
                    ),
                    arm_specialization=False,
                ),
            ),

            (
                "CASE H - 5x gym + shoulder focus",
                make_context(
                    base_context,
                    gym_days=(
                        1,
                        2,
                        3,
                        5,
                        6,
                    ),
                    muscle_priorities=(
                        make_priorities(
                            base_context,
                            high=(
                                "SIDE_DELTS",
                                "REAR_DELTS",
                            ),
                            maintenance=(
                                "QUADS",
                                "GLUTES",
                            ),
                        )
                    ),
                    arm_specialization=False,
                ),
            ),

            (
                "CASE I - 3x gym + chest/back focus",
                make_context(
                    base_context,
                    gym_days=(
                        1,
                        3,
                        5,
                    ),
                    muscle_priorities=(
                        make_priorities(
                            base_context,
                            high=(
                                "CHEST",
                                "BACK",
                            ),
                            maintenance=(
                                "QUADS",
                                "GLUTES",
                            ),
                        )
                    ),
                    arm_specialization=False,
                ),
            ),

            (
                "CASE J - 4x gym + dumbbell only",
                make_context(
                    base_context,
                    gym_days=(
                        1,
                        2,
                        4,
                        6,
                    ),
                    muscle_priorities=(
                        make_priorities(
                            base_context,
                            maintenance=(
                                "QUADS",
                                "GLUTES",
                            ),
                        )
                    ),
                    arm_specialization=False,
                    equipment_selection=(
                        "DUMBBELL",
                    ),
                    available_equipment=frozenset(
                        {
                            "DUMBBELL",
                            "BODYWEIGHT",
                        }
                    ),
                ),
            ),

            (
                "CASE K - 4x gym + barbell only",
                make_context(
                    base_context,
                    gym_days=(
                        1,
                        2,
                        4,
                        6,
                    ),
                    muscle_priorities=(
                        make_priorities(
                            base_context,
                            maintenance=(
                                "QUADS",
                                "GLUTES",
                            ),
                        )
                    ),
                    arm_specialization=False,
                    equipment_selection=(
                        "BARBELL",
                    ),
                    available_equipment=frozenset(
                        {
                            "BARBELL",
                            "BODYWEIGHT",
                        }
                    ),
                ),
            ),
        ]

        results = []

        for name, context in cases:
            passed = run_case(
                db,
                name,
                context,
            )

            results.append(
                (
                    name,
                    passed,
                )
            )

        print()
        print()
        print("=" * 90)
        print(
            "FORGE GENERATOR MATRIX SUMMARY"
        )
        print("=" * 90)

        for name, passed in results:
            print(
                f"{'PASS' if passed else 'FAIL':4} | "
                f"{name}"
            )

        passed_count = sum(
            1
            for _, passed in results
            if passed
        )

        print("-" * 90)

        print(
            f"Passed: "
            f"{passed_count}/{len(results)}"
        )

    finally:
        db.close()


if __name__ == "__main__":
    main()