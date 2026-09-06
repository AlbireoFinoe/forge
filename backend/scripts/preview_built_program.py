import argparse

from sqlalchemy import select

from app.core.database import (
    SessionLocal,
)
from app.generator.builder import (
    build_program_plan,
)
from app.generator.context import (
    build_generator_context,
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

        result = build_program_plan(
            db,
            context,
        )

        print()
        print(
            "FORGE Sequential Program"
        )
        print("=" * 90)

        for session in (
            result
            .fitted_program
            .sessions
        ):
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
        print("=" * 90)

        print(
            "Planning weekly remaining"
        )

        for muscle, remaining in sorted(
            result
            .planning_remaining_effective_sets
            .items()
        ):
            print(
                f"{muscle:<16}"
                f"{remaining}"
            )

        print()
        print(
            "Planning actual effective sets"
        )

        for muscle, actual in sorted(
            result
            .planning_actual_effective_sets
            .items()
        ):
            target = (
                result
                .volume_plan
                .targets[muscle]
                .target_effective_sets
            )

            print(
                f"{muscle:<16}"
                f"{actual:<6}"
                f" / {target}"
            )

    finally:
        db.close()


if __name__ == "__main__":
    main()