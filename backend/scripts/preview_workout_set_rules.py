import argparse
from decimal import Decimal

from sqlalchemy import func, select

from app.core.database import SessionLocal
from app.models.user import User
from app.models.workout_exercise import WorkoutExercise
from app.models.workout_session import WorkoutSession
from app.models.workout_set import WorkoutSet
from app.services.workout_service import (
    WorkoutSetValidationError,
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
                WorkoutSession.started_at.desc()
            )
        )

        if workout is None:
            raise RuntimeError(
                "No workout in progress"
            )

        exercise = db.scalar(
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

        if exercise is None:
            raise RuntimeError(
                "Workout exercise not found"
            )

        sets = db.scalars(
            select(
                WorkoutSet
            )
            .where(
                WorkoutSet.workout_exercise_id
                == exercise.id
            )
            .order_by(
                WorkoutSet.set_number
            )
        ).all()

        if len(sets) < 5:
            raise RuntimeError(
                "Expected at least 5 workout sets"
            )

        print()
        print("FORGE Workout Set Rules")
        print("=" * 80)
        print(
            f"Exercise: {exercise.exercise_name}"
        )
        print(
            f"Initial status: {exercise.status}"
        )

        print()
        print("1. Invalid RPE protection")
        print("-" * 80)

        set_two = sets[1]

        try:
            log_workout_set(
                db=db,
                user=user,
                workout_set_id=set_two.id,
                actual_reps=9,
                weight_kg=Decimal("70.00"),
                rpe=Decimal("11.0"),
            )

            raise RuntimeError(
                "Invalid RPE was accepted"
            )

        except WorkoutSetValidationError as exc:
            print(
                f"Blocked correctly: {exc}"
            )

        db.refresh(
            set_two
        )

        print(
            f"Set 2 completed after rejection: "
            f"{set_two.is_completed}"
        )
        print(
            f"Set 2 reps after rejection: "
            f"{set_two.actual_reps}"
        )
        print(
            f"Set 2 RPE after rejection: "
            f"{set_two.rpe}"
        )

        if set_two.is_completed:
            raise RuntimeError(
                "Invalid log modified Set 2"
            )

        print()
        print("2. Complete remaining sets")
        print("-" * 80)

        logs = [
            (sets[1], 9, "70.00", "8.0"),
            (sets[2], 9, "70.00", "8.5"),
            (sets[3], 8, "70.00", "9.0"),
            (sets[4], 8, "70.00", "9.0"),
        ]

        for (
            workout_set,
            reps,
            weight,
            rpe,
        ) in logs:
            result = log_workout_set(
                db=db,
                user=user,
                workout_set_id=workout_set.id,
                actual_reps=reps,
                weight_kg=Decimal(weight),
                rpe=Decimal(rpe),
            )

            print(
                f"Set {result.set_number}: "
                f"{result.actual_reps} reps "
                f"@ {result.weight_kg} kg "
                f"| RPE {result.rpe}"
            )

        db.refresh(
            exercise
        )

        completed_sets = db.scalar(
            select(
                func.count(
                    WorkoutSet.id
                )
            )
            .where(
                WorkoutSet.workout_exercise_id
                == exercise.id,
                WorkoutSet.is_completed
                .is_(True),
            )
        )

        print()
        print(
            f"Completed sets: "
            f"{completed_sets}/{exercise.target_sets}"
        )
        print(
            f"Exercise status: "
            f"{exercise.status}"
        )

        if (
            int(completed_sets or 0)
            != exercise.target_sets
        ):
            raise RuntimeError(
                "Not all sets are completed"
            )

        if exercise.status != "completed":
            raise RuntimeError(
                "Exercise was not marked completed"
            )

        print()
        print("=" * 80)
        print("WORKOUT SET RULES: PASS")

    finally:
        db.close()


if __name__ == "__main__":
    main()