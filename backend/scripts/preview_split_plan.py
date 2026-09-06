import argparse

from sqlalchemy import select

from app.core.database import SessionLocal
from app.generator.context import (
    GeneratorContextError,
    build_generator_context,
)
from app.generator.split import (
    SplitEngineError,
    generate_split_plan,
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
                User.email == args.email.lower()
            )
        )

        if user is None:
            print("User not found.")
            return

        try:
            context = build_generator_context(
                db,
                user,
            )

            plan = generate_split_plan(
                context
            )

        except (
            GeneratorContextError,
            SplitEngineError,
        ) as exc:
            print(
                f"Generator error: {exc}"
            )
            return

        sports_by_day = {}

        for sport in context.sports:
            sports_by_day.setdefault(
                sport.day_of_week,
                [],
            ).append(sport)

        print()
        print("FORGE Split Plan")
        print("=" * 80)

        for session in plan.sessions:
            day_name = DAY_NAMES[
                session.day_of_week
            ]

            print()
            print(
                f"Day {session.day_order} - "
                f"{day_name}"
            )

            print(
                f"Session: {session.name}"
            )

            print(
                "Focus:",
                ", ".join(
                    session.focus_muscles
                ),
            )

            print(
                "Sport conflict score:",
                session.sport_conflict_score,
            )

            print(
                "Recovery conflict score:",
                session.recovery_conflict_score,
            )

            if session.reason_codes:
                print(
                    "Reasons:",
                    ", ".join(
                        session.reason_codes
                    ),
                )

            day_sports = sports_by_day.get(
                session.day_of_week,
                [],
            )

            for sport in day_sports:
                print(
                    "Sport:",
                    f"{sport.sport_type} "
                    f"({sport.intensity}, "
                    f"{sport.duration_minutes} min)"
                )

        print()
        print("-" * 80)

        print(
            "Total sport conflict score:",
            plan.total_sport_conflict_score,
        )

        print(
            "Total recovery conflict score:",
            plan.total_recovery_conflict_score,
        )

        print(
            "Total optimization score:",
            plan.total_score,
        )

    finally:
        db.close()


if __name__ == "__main__":
    main()