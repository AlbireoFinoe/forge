import argparse

from sqlalchemy import func, select

from app.core.database import SessionLocal
from app.models.program_day import ProgramDay
from app.models.training_program import TrainingProgram
from app.models.user import User
from app.models.workout_exercise import WorkoutExercise
from app.models.workout_session import WorkoutSession
from app.models.workout_set import WorkoutSet
from app.services.workout_service import (
    WorkoutAlreadyInProgressError,
    start_workout,
)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--email",
        required=True,
    )
    parser.add_argument(
        "--day-order",
        type=int,
        default=1,
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

        row = db.execute(
            select(
                ProgramDay,
                TrainingProgram,
            )
            .join(
                TrainingProgram,
                ProgramDay.program_id
                == TrainingProgram.id,
            )
            .where(
                TrainingProgram.user_id
                == user.id,
                TrainingProgram.status
                == "active",
                ProgramDay.day_order
                == args.day_order,
            )
        ).one_or_none()

        if row is None:
            raise RuntimeError(
                "Active program day not found"
            )

        program_day, program = row

        print()
        print("FORGE Workout Start Smoke Test")
        print("=" * 80)
        print(
            f"User: {user.email}"
        )
        print(
            f"Program: {program.name}"
        )
        print(
            f"Program version: "
            f"{program.version_number}"
        )
        print(
            f"Day: {program_day.day_order}"
            f" - {program_day.name}"
        )
        print("=" * 80)

        workout = start_workout(
            db=db,
            user=user,
            program_day_id=program_day.id,
        )

        exercise_count = db.scalar(
            select(
                func.count(
                    WorkoutExercise.id
                )
            ).where(
                WorkoutExercise.workout_session_id
                == workout.id
            )
        )

        set_count = db.scalar(
            select(
                func.count(
                    WorkoutSet.id
                )
            )
            .join(
                WorkoutExercise,
                WorkoutSet.workout_exercise_id
                == WorkoutExercise.id,
            )
            .where(
                WorkoutExercise.workout_session_id
                == workout.id
            )
        )

        exercises = db.scalars(
            select(
                WorkoutExercise
            )
            .where(
                WorkoutExercise.workout_session_id
                == workout.id
            )
            .order_by(
                WorkoutExercise.exercise_order
            )
        ).all()

        print(
            f"Workout ID: {workout.id}"
        )
        print(
            f"Status: {workout.status}"
        )
        print(
            f"Snapshot program version: "
            f"{workout.program_version_number}"
        )
        print(
            f"Snapshot program name: "
            f"{workout.program_name}"
        )
        print(
            f"Snapshot day name: "
            f"{workout.day_name}"
        )
        print(
            f"Workout exercises: "
            f"{exercise_count}"
        )
        print(
            f"Workout sets: "
            f"{set_count}"
        )

        print()
        print("Exercises")
        print("-" * 80)

        for exercise in exercises:
            print(
                f"{exercise.exercise_order}. "
                f"{exercise.exercise_name}"
            )
            print(
                f"   target: "
                f"{exercise.target_sets} sets "
                f"x "
                f"{exercise.target_min_reps}-"
                f"{exercise.target_max_reps} reps "
                f"| rest "
                f"{exercise.target_rest_seconds}s"
            )

        print()
        print("=" * 80)
        print("START WORKOUT: PASS")

    except WorkoutAlreadyInProgressError as exc:
        print()
        print(
            "START WORKOUT: BLOCKED"
        )
        print(str(exc))

    finally:
        db.close()


if __name__ == "__main__":
    main()