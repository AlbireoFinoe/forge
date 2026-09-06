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

        context = build_generator_context(
            db,
            user,
        )

        volume = calculate_volume_plan(
            context
        )

        split = generate_split_plan(
            context
        )

        distribution = distribute_volume(
            context,
            volume,
            split,
        )

        pool = load_exercise_pool(
            db,
            context,
        )

        plan = select_exercises(
            context=context,
            split_plan=split,
            distribution=distribution,
            pool=pool,
        )

        print()
        print(
            "FORGE Exercise Selection"
        )
        print("=" * 90)

        for session in plan.sessions:
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
                f"Physical sets: "
                f"{session.physical_sets}"
            )

            print()

            for exercise in session.exercises:
                item = exercise.exercise

                print(
                    f"  {exercise.exercise_order}. "
                    f"{item.name}"
                )

                print(
                    f"     {exercise.sets} sets "
                    f"x "
                    f"{exercise.min_reps}-"
                    f"{exercise.max_reps} reps "
                    f"| rest "
                    f"{exercise.rest_seconds}s"
                )

                print(
                    "     reasons:",
                    ", ".join(
                        exercise.reason_codes
                    ),
                )

            print()
            print(
                "  Muscle demand:"
            )

            for muscle in sorted(
                session.target_effective_sets
            ):
                target = (
                    session
                    .target_effective_sets[
                        muscle
                    ]
                )

                achieved = (
                    session
                    .achieved_effective_sets[
                        muscle
                    ]
                )

                remaining = (
                    session
                    .remaining_effective_sets[
                        muscle
                    ]
                )

                print(
                    f"    {muscle:<16}"
                    f"target={target:<5}"
                    f"achieved={achieved:<5}"
                    f"remaining={remaining}"
                )

        print()
        print("=" * 90)

    finally:
        db.close()


if __name__ == "__main__":
    main()