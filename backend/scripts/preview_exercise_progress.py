import argparse

from sqlalchemy import select

from app.core.database import SessionLocal
from app.models.user import User
from app.services.progress_service import (
    get_exercise_progress_analysis,
)
from app.services.progress_service import (
    ExerciseHistoryNotFoundError,
    get_exercise_progress_analysis,
)


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--email",
        required=True,
    )

    parser.add_argument(
        "--exercise-code",
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

        try:
            result = (
                get_exercise_progress_analysis(
                    db=db,
                    user=user,
                    exercise_code=(
                        args.exercise_code
                    ),
                )
            )
        except ExerciseHistoryNotFoundError:
            print()
            print(
                "FORGE Exercise Progress Analysis"
            )
            print("=" * 80)
            print(
                f"Exercise code: "
                f"{args.exercise_code}"
            )
            print(
                "History entries: 0"
            )
            print(
                "Completed sessions: 0"
            )
            print(
                "Trend: insufficient_data"
            )
            print("=" * 80)
            print(
                "EXERCISE PROGRESS: "
                "PASS (INSUFFICIENT DATA)"
            )
            return

        print()
        print(
            "FORGE Exercise Progress Analysis"
        )
        print("=" * 80)

        print(
            f"Exercise: "
            f"{result.exercise_name}"
        )

        print(
            f"History entries: "
            f"{result.history_entries}"
        )

        print(
            f"Completed sessions: "
            f"{result.completed_sessions}"
        )

        print()

        print(
            f"Best weight: "
            f"{result.best_weight_kg} kg"
        )

        print(
            f"Best weight reps: "
            f"{result.best_weight_reps}"
        )

        print(
            f"Best completed-session volume: "
            f"{result.best_session_volume_kg} kg"
        )

        print()
        print("Latest completed session")
        print("-" * 80)

        print(
            f"Top weight: "
            f"{result.latest_top_weight_kg} kg"
        )

        print(
            f"Volume: "
            f"{result.latest_volume_kg} kg"
        )

        print(
            f"Average RPE: "
            f"{result.latest_average_rpe}"
        )

        print()
        print("Previous completed session")
        print("-" * 80)

        print(
            f"Top weight: "
            f"{result.previous_top_weight_kg} kg"
        )

        print(
            f"Volume: "
            f"{result.previous_volume_kg} kg"
        )

        print(
            f"Average RPE: "
            f"{result.previous_average_rpe}"
        )

        print()

        print(
            f"Volume change: "
            f"{result.volume_change_percent}%"
        )

        print(
            f"Trend: {result.trend}"
        )

        print("=" * 80)
        print(
            "EXERCISE PROGRESS: PASS"
        )

    finally:
        db.close()


if __name__ == "__main__":
    main()