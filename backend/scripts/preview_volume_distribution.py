import argparse

from sqlalchemy import select

from app.core.database import SessionLocal
from app.generator.context import (
    build_generator_context,
)
from app.generator.distribution import (
    distribute_volume,
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

        distribution = (
            distribute_volume(
                context,
                volume_plan,
                split_plan,
            )
        )

        print()
        print(
            "FORGE Volume Distribution"
        )
        print("=" * 80)

        for session in split_plan.sessions:
            print()
            print(
                f"Day {session.day_order} - "
                f"{DAY_NAMES[session.day_of_week]}"
            )

            print(
                f"Session: {session.name}"
            )

            day_allocations = [
                item
                for item
                in distribution.allocations
                if item.day_order
                == session.day_order
            ]

            total = 0

            for item in day_allocations:
                print(
                    f"  {item.muscle_code:<16}"
                    f"{item.target_effective_sets:>3}"
                )

                total += (
                    item.target_effective_sets
                )

            print(
                f"  {'EFFECTIVE DEMAND':<16}"
                f"{total:>3}"
            )

        print()
        print("=" * 80)

        print(
            "Weekly muscle totals"
        )

        for muscle_code in sorted(
            volume_plan.targets
        ):
            items = (
                distribution
                .allocations_for_muscle(
                    muscle_code
                )
            )

            total = sum(
                item.target_effective_sets
                for item in items
            )

            target = (
                volume_plan
                .targets[muscle_code]
                .target_effective_sets
            )

            print(
                f"{muscle_code:<16}"
                f"{total:>3}"
                f" / {target:<3}"
            )

    finally:
        db.close()


if __name__ == "__main__":
    main()