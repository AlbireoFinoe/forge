import argparse

from sqlalchemy import select

from app.core.database import SessionLocal
from app.models.user import User
from app.services.progress_service import (
    get_progress_overview,
)


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
                User.email == args.email
            )
        )

        if user is None:
            raise RuntimeError(
                "User not found"
            )

        overview = (
            get_progress_overview(
                db=db,
                user=user,
            )
        )

        print()
        print(
            "FORGE Progress Overview"
        )
        print("=" * 90)

        print(
            f"Total exercises: "
            f"{overview.total_exercises}"
        )

        print(
            f"Improving: "
            f"{overview.improving}"
        )

        print(
            f"Stable: "
            f"{overview.stable}"
        )

        print(
            f"Declining: "
            f"{overview.declining}"
        )

        print(
            f"Insufficient data: "
            f"{overview.insufficient_data}"
        )

        print()
        print("-" * 90)

        for item in overview.exercises:
            print(
                f"{item.exercise_name}"
            )

            print(
                f"  Code: "
                f"{item.exercise_code}"
            )

            print(
                f"  Trend: "
                f"{item.trend}"
            )

            print(
                f"  Completed sessions: "
                f"{item.completed_sessions}"
            )

            print(
                f"  Best weight: "
                f"{item.best_weight_kg}"
            )

            print(
                f"  Latest volume: "
                f"{item.latest_volume_kg}"
            )

            print(
                f"  Change: "
                f"{item.volume_change_percent}%"
            )

            print()

        print("=" * 90)
        print(
            "PROGRESS OVERVIEW: PASS"
        )

    finally:
        db.close()


if __name__ == "__main__":
    main()