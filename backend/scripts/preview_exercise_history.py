import argparse

from sqlalchemy import select

from app.core.database import SessionLocal
from app.models.user import User
from app.services.progress_service import (
    get_exercise_history,
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

        history = get_exercise_history(
            db=db,
            user=user,
            exercise_code=(
                args.exercise_code
            ),
        )

        print()
        print(
            "FORGE Exercise History"
        )
        print("=" * 80)
        print(
            f"Exercise code: "
            f"{args.exercise_code}"
        )
        print(
            f"Entries: {len(history)}"
        )
        print()

        for item in history:
            print(
                item.workout_completed_at
            )
            print(
                f"  {item.exercise_name}"
            )
            print(
                f"  Status: "
                f"{item.exercise_status}"
            )
            print(
                f"  Sets: "
                f"{item.completed_sets}"
                f"/{item.target_sets} "
                f"({item.set_completion_rate}%)"
            )
            print(
                f"  Reps: "
                f"{item.total_reps}"
            )
            print(
                f"  Top weight: "
                f"{item.top_weight_kg} kg"
            )
            print(
                f"  Volume: "
                f"{item.external_volume_kg} kg"
            )
            print(
                f"  Average RPE: "
                f"{item.average_rpe}"
            )
            print()

        print("=" * 80)
        print(
            "EXERCISE HISTORY: PASS"
        )

    finally:
        db.close()


if __name__ == "__main__":
    main()