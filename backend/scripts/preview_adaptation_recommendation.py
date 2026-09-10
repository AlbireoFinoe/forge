import argparse

from sqlalchemy import select

from app.core.database import SessionLocal
from app.models.user import User
from app.services.adaptation_service import (
    get_exercise_adaptation_recommendation,
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

        result = (
            get_exercise_adaptation_recommendation(
                db=db,
                user=user,
                exercise_code=(
                    args.exercise_code
                ),
            )
        )

        print()
        print(
            "FORGE Adaptation Recommendation"
        )
        print("=" * 80)

        print(
            f"Exercise: "
            f"{result.exercise_name}"
        )

        print(
            f"Code: "
            f"{result.exercise_code}"
        )

        print(
            f"Completed sessions: "
            f"{result.completed_sessions}"
        )

        print(
            f"Trend: {result.trend}"
        )

        print(
            f"Latest weight: "
            f"{result.latest_weight_kg}"
        )

        print(
            f"Average RPE: "
            f"{result.latest_average_rpe}"
        )

        print(
            f"Volume change: "
            f"{result.volume_change_percent}"
        )

        print()
        print(
            f"ACTION: {result.action}"
        )

        print(
            f"Confidence: "
            f"{result.confidence}"
        )

        print(
            f"Reason codes: "
            f"{result.reason_codes}"
        )

        print(
            f"Load change: "
            f"{result.suggested_load_change_percent}%"
        )

        print(
            f"Rep change: "
            f"{result.suggested_rep_change}"
        )

        print(
            f"Set change: "
            f"{result.suggested_set_change}"
        )

        print("=" * 80)
        print(
            "ADAPTATION RECOMMENDATION: PASS"
        )

    finally:
        db.close()


if __name__ == "__main__":
    main()