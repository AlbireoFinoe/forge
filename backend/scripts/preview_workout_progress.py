import argparse

from sqlalchemy import select

from app.core.database import SessionLocal
from app.models.user import User
from app.models.workout_session import WorkoutSession
from app.services.progress_service import (
    get_workout_progress_summary,
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

        workout = db.scalar(
            select(
                WorkoutSession
            )
            .where(
                WorkoutSession.user_id
                == user.id,
                WorkoutSession.status
                == "completed",
            )
            .order_by(
                WorkoutSession.completed_at
                .desc()
            )
        )

        if workout is None:
            raise RuntimeError(
                "No completed workout found"
            )

        summary = (
            get_workout_progress_summary(
                db=db,
                user=user,
                workout_session_id=(
                    workout.id
                ),
            )
        )

        print()
        print(
            "FORGE Workout Progress Summary"
        )
        print("=" * 80)

        print(
            f"Workout ID: "
            f"{summary.workout_id}"
        )

        print(
            f"Program version: "
            f"{summary.program_version_number}"
        )

        print(
            f"Day: {summary.day_name}"
        )

        print(
            f"Status: {summary.status}"
        )

        print(
            f"Duration: "
            f"{summary.duration_minutes} min"
        )

        print()

        print(
            f"Exercises: "
            f"{summary.total_exercises}"
        )

        print(
            f"Completed exercises: "
            f"{summary.completed_exercises}"
        )

        print(
            f"Skipped exercises: "
            f"{summary.skipped_exercises}"
        )

        print()

        print(
            f"Sets: "
            f"{summary.completed_sets}"
            f"/{summary.planned_sets}"
        )

        print(
            f"Set completion: "
            f"{summary.set_completion_rate}%"
        )

        print(
            f"Total reps: "
            f"{summary.total_reps}"
        )

        print(
            f"External volume: "
            f"{summary.external_volume_kg} kg"
        )

        print(
            f"Average RPE: "
            f"{summary.average_rpe}"
        )

        print("=" * 80)
        print(
            "WORKOUT PROGRESS: PASS"
        )

    finally:
        db.close()


if __name__ == "__main__":
    main()