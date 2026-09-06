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
    load_exercise_pool,
)
from app.generator.fitter import (
    fit_program_to_constraints,
)
from app.generator.selector import (
    select_exercises,
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

        context = (
            build_generator_context(
                db,
                user,
            )
        )

        volume = (
            calculate_volume_plan(
                context
            )
        )

        split = (
            generate_split_plan(
                context
            )
        )

        distribution = (
            distribute_volume(
                context,
                volume,
                split,
            )
        )

        pool = load_exercise_pool(
            db,
            context,
        )

        selection = select_exercises(
            context=context,
            split_plan=split,
            distribution=distribution,
            pool=pool,
        )

        fitted = (
            fit_program_to_constraints(
                context,
                selection,
            )
        )

        print()
        print(
            "FORGE Fitted Program"
        )
        print("=" * 90)

        for session in fitted.sessions:
            print()
            print(
                f"Day {session.day_order} - "
                f"{DAY_NAMES[session.day_of_week]}"
            )

            print(
                f"Session: "
                f"{session.session_name}"
            )

            print(
                f"Duration: "
                f"{session.estimated_duration_minutes}"
                f" / "
                f"{session.available_duration_minutes}"
                f" min"
            )

            print(
                f"Physical sets: "
                f"{session.physical_sets}"
            )

            if session.reason_codes:
                print(
                    "Adjustments:",
                    ", ".join(
                        session.reason_codes
                    ),
                )

            print()

            for order, item in enumerate(
                session.exercises,
                start=1,
            ):
                selected = (
                    item.exercise
                )

                print(
                    f"  {order}. "
                    f"{selected.exercise.name}"
                )

                print(
                    f"     {item.sets} sets x "
                    f"{selected.min_reps}-"
                    f"{selected.max_reps} reps "
                    f"| rest "
                    f"{selected.rest_seconds}s"
                )

            print()
            print(
                "  Remaining demand:"
            )

            for muscle in sorted(
                session.remaining_effective_sets
            ):
                remaining = (
                    session
                    .remaining_effective_sets[
                        muscle
                    ]
                )

                if remaining > 0:
                    print(
                        f"    {muscle:<16}"
                        f"{remaining}"
                    )

        print()
        print("=" * 90)

    finally:
        db.close()


if __name__ == "__main__":
    main()