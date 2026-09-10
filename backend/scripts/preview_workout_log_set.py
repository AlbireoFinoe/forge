import argparse
from decimal import Decimal

from sqlalchemy import select

from app.core.database import SessionLocal
from app.models.user import User
from app.models.workout_exercise import WorkoutExercise
from app.models.workout_session import WorkoutSession
from app.models.workout_set import WorkoutSet
from app.services.workout_service import (
    log_workout_set,
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
                == "in_progress",
            )
            .order_by(
                WorkoutSession.started_at
                .desc()
            )
        )

        if workout is None:
            raise RuntimeError(
                "No workout in progress"
            )

        workout_exercise = db.scalar(
            select(
                WorkoutExercise
            )
            .where(
                WorkoutExercise.workout_session_id
                == workout.id,
                WorkoutExercise.exercise_order
                == 1,
            )
        )

        if workout_exercise is None:
            raise RuntimeError(
                "Workout exercise not found"
            )

        workout_set = db.scalar(
            select(
                WorkoutSet
            )
            .where(
                WorkoutSet.workout_exercise_id
                == workout_exercise.id,
                WorkoutSet.set_number
                == 1,
            )
        )

        if workout_set is None:
            raise RuntimeError(
                "Workout set not found"
            )

        print()
        print("FORGE Workout Set Log Smoke Test")
        print("=" * 80)
        print(
            f"Workout ID: {workout.id}"
        )
        print(
            f"Exercise: "
            f"{workout_exercise.exercise_name}"
        )
        print(
            f"Set: {workout_set.set_number}"
        )
        print()

        result = log_workout_set(
            db=db,
            user=user,
            workout_set_id=workout_set.id,
            actual_reps=10,
            weight_kg=Decimal("70.00"),
            rpe=Decimal("8.0"),
        )

        db.refresh(
            workout_exercise
        )

        print(
            f"Actual reps: "
            f"{result.actual_reps}"
        )
        print(
            f"Weight: "
            f"{result.weight_kg} kg"
        )
        print(
            f"RPE: {result.rpe}"
        )
        print(
            f"Completed: "
            f"{result.is_completed}"
        )
        print(
            f"Completed at: "
            f"{result.completed_at}"
        )
        print(
            f"Exercise status: "
            f"{workout_exercise.status}"
        )

        print()
        print("=" * 80)
        print("LOG WORKOUT SET: PASS")

    finally:
        db.close()


if __name__ == "__main__":
    main()