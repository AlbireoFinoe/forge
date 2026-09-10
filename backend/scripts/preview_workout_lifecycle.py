import argparse

from sqlalchemy import func, select

from app.core.database import SessionLocal
from app.models.user import User
from app.models.workout_exercise import WorkoutExercise
from app.models.workout_session import WorkoutSession
from app.services.workout_service import (
    WorkoutHasPendingExercisesError,
    finish_workout,
    skip_workout_exercise,
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

        print()
        print("FORGE Workout Lifecycle Smoke Test")
        print("=" * 80)
        print(
            f"Workout ID: {workout.id}"
        )
        print(
            f"Initial status: {workout.status}"
        )

        pending_before = db.scalar(
            select(
                func.count(
                    WorkoutExercise.id
                )
            ).where(
                WorkoutExercise.workout_session_id
                == workout.id,
                WorkoutExercise.status
                == "pending",
            )
        )

        completed_before = db.scalar(
            select(
                func.count(
                    WorkoutExercise.id
                )
            ).where(
                WorkoutExercise.workout_session_id
                == workout.id,
                WorkoutExercise.status
                == "completed",
            )
        )

        print(
            f"Completed exercises: "
            f"{completed_before}"
        )
        print(
            f"Pending exercises: "
            f"{pending_before}"
        )

        print()
        print("1. Finish protection")
        print("-" * 80)

        try:
            finish_workout(
                db=db,
                user=user,
                workout_session_id=(
                    workout.id
                ),
            )

            raise RuntimeError(
                "Workout finished despite "
                "pending exercises"
            )

        except (
            WorkoutHasPendingExercisesError
        ) as exc:
            print(
                f"Blocked correctly: {exc}"
            )

        db.refresh(
            workout
        )

        print(
            f"Status after blocked finish: "
            f"{workout.status}"
        )

        if workout.status != "in_progress":
            raise RuntimeError(
                "Blocked finish changed "
                "workout status"
            )

        print()
        print("2. Skip remaining exercises")
        print("-" * 80)

        pending_exercises = db.scalars(
            select(
                WorkoutExercise
            )
            .where(
                WorkoutExercise.workout_session_id
                == workout.id,
                WorkoutExercise.status
                == "pending",
            )
            .order_by(
                WorkoutExercise.exercise_order
            )
        ).all()

        for exercise in pending_exercises:
            result = (
                skip_workout_exercise(
                    db=db,
                    user=user,
                    workout_exercise_id=(
                        exercise.id
                    ),
                )
            )

            print(
                f"Skipped: "
                f"{result.exercise_name}"
            )

        print()
        print("3. Finish workout")
        print("-" * 80)

        result = finish_workout(
            db=db,
            user=user,
            workout_session_id=(
                workout.id
            ),
        )

        completed_count = db.scalar(
            select(
                func.count(
                    WorkoutExercise.id
                )
            ).where(
                WorkoutExercise.workout_session_id
                == workout.id,
                WorkoutExercise.status
                == "completed",
            )
        )

        skipped_count = db.scalar(
            select(
                func.count(
                    WorkoutExercise.id
                )
            ).where(
                WorkoutExercise.workout_session_id
                == workout.id,
                WorkoutExercise.status
                == "skipped",
            )
        )

        pending_count = db.scalar(
            select(
                func.count(
                    WorkoutExercise.id
                )
            ).where(
                WorkoutExercise.workout_session_id
                == workout.id,
                WorkoutExercise.status
                == "pending",
            )
        )

        print(
            f"Final status: {result.status}"
        )
        print(
            f"Completed at: "
            f"{result.completed_at}"
        )
        print(
            f"Completed exercises: "
            f"{completed_count}"
        )
        print(
            f"Skipped exercises: "
            f"{skipped_count}"
        )
        print(
            f"Pending exercises: "
            f"{pending_count}"
        )

        if result.status != "completed":
            raise RuntimeError(
                "Workout was not completed"
            )

        if result.completed_at is None:
            raise RuntimeError(
                "completed_at was not set"
            )

        if int(pending_count or 0) != 0:
            raise RuntimeError(
                "Pending exercises remain"
            )

        print()
        print("=" * 80)
        print("WORKOUT LIFECYCLE: PASS")

    finally:
        db.close()


if __name__ == "__main__":
    main()