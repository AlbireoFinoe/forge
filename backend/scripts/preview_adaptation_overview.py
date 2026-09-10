import argparse

from sqlalchemy import select

from app.core.database import SessionLocal
from app.models.user import User
from app.services.adaptation_service import (
    get_adaptation_overview,
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
            get_adaptation_overview(
                db=db,
                user=user,
            )
        )

        print()
        print(
            "FORGE Adaptation Overview"
        )
        print("=" * 100)

        print(
            f"Total exercises: "
            f"{overview.total_exercises}"
        )

        print(
            f"Progress load: "
            f"{overview.progress_load}"
        )

        print(
            f"Progress reps: "
            f"{overview.progress_reps}"
        )

        print(
            f"Hold load: "
            f"{overview.hold_load}"
        )

        print(
            f"Keep current: "
            f"{overview.keep_current}"
        )

        print(
            f"Reduce stress: "
            f"{overview.reduce_stress}"
        )

        print()
        print("-" * 100)

        for item in overview.recommendations:
            print(
                item.exercise_name
                or item.exercise_code
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
                f"  Action: "
                f"{item.action}"
            )

            print(
                f"  Confidence: "
                f"{item.confidence}"
            )

            print(
                f"  Reasons: "
                f"{item.reason_codes}"
            )

            print(
                f"  Load change: "
                f"{item.suggested_load_change_percent}"
            )

            print(
                f"  Rep change: "
                f"{item.suggested_rep_change}"
            )

            print(
                f"  Set change: "
                f"{item.suggested_set_change}"
            )

            print()

        print("=" * 100)
        print(
            "ADAPTATION OVERVIEW: PASS"
        )

    finally:
        db.close()


if __name__ == "__main__":
    main()