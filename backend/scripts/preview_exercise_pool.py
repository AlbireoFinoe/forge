import argparse

from sqlalchemy import select

from app.core.database import SessionLocal
from app.generator.context import (
    build_generator_context,
)
from app.generator.distribution import (
    distribute_volume,
)
from app.generator.exercise_pool import (
    get_candidates_for_muscle,
    load_exercise_pool,
)
from app.generator.split import (
    generate_split_plan,
)
from app.generator.volume import (
    calculate_volume_plan,
)
from app.models.user import User


DAY_NAMES = {
    1: "Monday",
    2: "Tuesday",
    3: "Wednesday",
    4: "Thursday",
    5: "Friday",
    6: "Saturday",
    7: "Sunday",
}


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

        context = build_generator_context(
            db,
            user,
        )

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

        distribution = distribute_volume(
            context,
            volume_plan,
            split_plan,
        )

        pool = load_exercise_pool(
            db,
            context,
        )

        print()
        print("FORGE Exercise Pool")
        print("=" * 80)

        print(
            "Eligible exercises:",
            len(pool),
        )

        print(
            "Available equipment:",
            ", ".join(
                sorted(
                    context.available_equipment
                )
            ),
        )

        for session in split_plan.sessions:
            print()
            print(
                f"Day {session.day_order} - "
                f"{DAY_NAMES[session.day_of_week]}"
            )

            print(
                f"Session: {session.name}"
            )

            allocations = [
                item
                for item
                in distribution.allocations
                if item.day_order
                == session.day_order
            ]

            for allocation in allocations:
                muscle = (
                    allocation.muscle_code
                )

                candidates = (
                    get_candidates_for_muscle(
                        pool,
                        muscle,
                    )
                )

                primary = [
                    exercise
                    for exercise in candidates
                    if exercise.primary_muscle
                    == muscle
                ]

                secondary = [
                    exercise
                    for exercise in candidates
                    if exercise.primary_muscle
                    != muscle
                ]

                print(
                    f"  {muscle:<16}"
                    f"target="
                    f"{allocation.target_effective_sets:<3}"
                    f" primary="
                    f"{len(primary):<3}"
                    f" secondary="
                    f"{len(secondary):<3}"
                )

                examples = (
                    primary[:2]
                    if primary
                    else secondary[:2]
                )

                if examples:
                    print(
                        "    examples:",
                        ", ".join(
                            exercise.name
                            for exercise
                            in examples
                        ),
                    )

        print()
        print("=" * 80)

    finally:
        db.close()


if __name__ == "__main__":
    main()