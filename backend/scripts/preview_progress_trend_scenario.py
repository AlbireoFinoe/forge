import argparse
from decimal import Decimal

from sqlalchemy import select

from app.core.database import SessionLocal
from app.models.program_day import ProgramDay
from app.models.training_program import TrainingProgram
from app.models.user import User
from app.models.workout_exercise import WorkoutExercise
from app.models.workout_set import WorkoutSet
from app.services.progress_service import (
    get_exercise_progress_analysis,
)
from app.services.workout_service import (
    finish_workout,
    log_workout_set,
    skip_workout_exercise,
    start_workout,
)


EXERCISE_CODE = "BARBELL_OVERHEAD_PRESS"


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

        program_day = db.scalar(
            select(
                ProgramDay
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
                ProgramDay.day_order == 1,
            )
        )

        if program_day is None:
            raise RuntimeError(
                "Active Day 1 not found"
            )

        print()
        print(
            "FORGE Controlled Progress Trend Scenario"
        )
        print("=" * 80)

        workout = start_workout(
            db=db,
            user=user,
            program_day_id=program_day.id,
        )

        print(
            f"Workout started: {workout.id}"
        )

        exercise = db.scalar(
            select(
                WorkoutExercise
            ).where(
                WorkoutExercise.workout_session_id
                == workout.id,
                WorkoutExercise.exercise_code
                == EXERCISE_CODE,
            )
        )

        if exercise is None:
            raise RuntimeError(
                "OHP not found in workout"
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

        planned_logs = [
            (10, "72.50", "8.0"),
            (9, "72.50", "8.5"),
            (9, "72.50", "8.5"),
            (9, "72.50", "9.0"),
            (8, "72.50", "9.0"),
        ]

        if len(sets) != len(planned_logs):
            raise RuntimeError(
                "Unexpected OHP set count"
            )

        print()
        print("Logging completed OHP")
        print("-" * 80)

        for workout_set, log in zip(
            sets,
            planned_logs,
        ):
            reps, weight, rpe = log

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

        print(
            f"OHP status: {exercise.status}"
        )

        if exercise.status != "completed":
            raise RuntimeError(
                "OHP was not completed"
            )

        other_exercises = db.scalars(
            select(
                WorkoutExercise
            )
            .where(
                WorkoutExercise.workout_session_id
                == workout.id,
                WorkoutExercise.id
                != exercise.id,
            )
            .order_by(
                WorkoutExercise.exercise_order
            )
        ).all()

        print()
        print("Skipping other exercises")
        print("-" * 80)

        for other in other_exercises:
            result = skip_workout_exercise(
                db=db,
                user=user,
                workout_exercise_id=other.id,
            )

            print(
                f"Skipped: "
                f"{result.exercise_name}"
            )

        finished = finish_workout(
            db=db,
            user=user,
            workout_session_id=workout.id,
        )

        print()
        print(
            f"Workout status: "
            f"{finished.status}"
        )

        analysis = (
            get_exercise_progress_analysis(
                db=db,
                user=user,
                exercise_code=(
                    EXERCISE_CODE
                ),
            )
        )

        print()
        print("Progress Analysis")
        print("-" * 80)

        print(
            f"Completed sessions: "
            f"{analysis.completed_sessions}"
        )

        print(
            f"Best weight: "
            f"{analysis.best_weight_kg} kg"
        )

        print(
            f"Latest volume: "
            f"{analysis.latest_volume_kg} kg"
        )

        print(
            f"Previous volume: "
            f"{analysis.previous_volume_kg} kg"
        )

        print(
            f"Volume change: "
            f"{analysis.volume_change_percent}%"
        )

        print(
            f"Trend: {analysis.trend}"
        )

        if analysis.completed_sessions < 2:
            raise RuntimeError(
                "Expected at least 2 "
                "completed sessions"
            )

        if analysis.trend != "improving":
            raise RuntimeError(
                "Expected improving trend"
            )

        if (
            analysis.best_weight_kg
            != Decimal("72.50")
        ):
            raise RuntimeError(
                "Expected new best weight "
                "of 72.50 kg"
            )

        print()
        print("=" * 80)
        print(
            "CONTROLLED PROGRESSION: PASS"
        )

    finally:
        db.close()


if __name__ == "__main__":
    main()