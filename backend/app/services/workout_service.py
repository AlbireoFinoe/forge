import uuid
from datetime import datetime, timezone
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.exercise import Exercise
from app.models.program_day import ProgramDay
from app.models.program_exercise import ProgramExercise
from app.models.training_program import TrainingProgram
from app.models.user import User
from app.models.workout_exercise import WorkoutExercise
from app.models.workout_session import WorkoutSession
from app.models.workout_set import WorkoutSet


class WorkoutError(Exception):
    pass


class WorkoutAlreadyInProgressError(WorkoutError):
    pass


class ProgramDayNotFoundError(WorkoutError):
    pass


class EmptyProgramDayError(WorkoutError):
    pass


class WorkoutSetNotFoundError(WorkoutError):
    pass


class WorkoutNotInProgressError(WorkoutError):
    pass


class WorkoutExerciseSkippedError(WorkoutError):
    pass


class WorkoutSetValidationError(WorkoutError):
    pass


class WorkoutExerciseNotFoundError(WorkoutError):
    pass


class WorkoutExerciseAlreadyCompletedError(WorkoutError):
    pass


class WorkoutHasPendingExercisesError(WorkoutError):
    pass


class WorkoutSessionNotFoundError(WorkoutError):
    pass


def get_in_progress_workout(
    db: Session,
    user: User,
) -> WorkoutSession | None:
    return db.scalar(
        select(
            WorkoutSession
        )
        .where(
            WorkoutSession.user_id == user.id,
            WorkoutSession.status == "in_progress",
        )
        .order_by(
            WorkoutSession.started_at.desc()
        )
        .limit(1)
    )


def _get_active_program_day(
    db: Session,
    user: User,
    program_day_id: uuid.UUID,
):
    return db.execute(
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
            ProgramDay.id == program_day_id,
            TrainingProgram.user_id == user.id,
            TrainingProgram.status == "active",
        )
    ).one_or_none()


def _get_program_exercises(
    db: Session,
    program_day_id: uuid.UUID,
):
    return db.execute(
        select(
            ProgramExercise,
            Exercise,
        )
        .join(
            Exercise,
            ProgramExercise.exercise_id
            == Exercise.id,
        )
        .where(
            ProgramExercise.program_day_id
            == program_day_id
        )
        .order_by(
            ProgramExercise.exercise_order
        )
    ).all()


def start_workout(
    db: Session,
    user: User,
    program_day_id: uuid.UUID,
) -> WorkoutSession:
    try:
        existing_workout = (
            get_in_progress_workout(
                db,
                user,
            )
        )

        if existing_workout is not None:
            raise WorkoutAlreadyInProgressError(
                "User already has a workout "
                "in progress"
            )

        program_day_row = (
            _get_active_program_day(
                db,
                user,
                program_day_id,
            )
        )

        if program_day_row is None:
            raise ProgramDayNotFoundError(
                "Program day was not found "
                "in the active training program"
            )

        program_day, program = (
            program_day_row
        )

        exercise_rows = (
            _get_program_exercises(
                db,
                program_day.id,
            )
        )

        if not exercise_rows:
            raise EmptyProgramDayError(
                "Program day contains no exercises"
            )

        workout_session = WorkoutSession(
            user_id=user.id,
            training_program_id=program.id,
            program_day_id=program_day.id,
            program_version_number=(
                program.version_number
            ),
            program_name=program.name,
            day_name=program_day.name,
            day_of_week=(
                program_day.day_of_week
            ),
            day_order=(
                program_day.day_order
            ),
            status="in_progress",
        )

        db.add(
            workout_session
        )
        db.flush()

        for (
            program_exercise,
            exercise,
        ) in exercise_rows:
            workout_exercise = (
                WorkoutExercise(
                    workout_session_id=(
                        workout_session.id
                    ),
                    program_exercise_id=(
                        program_exercise.id
                    ),
                    exercise_id=exercise.id,
                    exercise_code=exercise.code,
                    exercise_name=exercise.name,
                    exercise_order=(
                        program_exercise
                        .exercise_order
                    ),
                    target_sets=(
                        program_exercise.sets
                    ),
                    target_min_reps=(
                        program_exercise
                        .min_reps
                    ),
                    target_max_reps=(
                        program_exercise
                        .max_reps
                    ),
                    target_rest_seconds=(
                        program_exercise
                        .rest_seconds
                    ),
                    status="pending",
                )
            )

            db.add(
                workout_exercise
            )
            db.flush()

            for set_number in range(
                1,
                program_exercise.sets + 1,
            ):
                workout_set = WorkoutSet(
                    workout_exercise_id=(
                        workout_exercise.id
                    ),
                    set_number=set_number,
                    is_completed=False,
                )

                db.add(
                    workout_set
                )

        db.commit()
        db.refresh(
            workout_session
        )

        return workout_session

    except Exception:
        db.rollback()
        raise


def _get_workout_exercise_for_user(
    db: Session,
    user: User,
    workout_exercise_id: uuid.UUID,
):
    return db.execute(
        select(
            WorkoutExercise,
            WorkoutSession,
        )
        .join(
            WorkoutSession,
            WorkoutExercise.workout_session_id
            == WorkoutSession.id,
        )
        .where(
            WorkoutExercise.id
            == workout_exercise_id,
            WorkoutSession.user_id
            == user.id,
        )
    ).one_or_none()


def skip_workout_exercise(
    db: Session,
    user: User,
    workout_exercise_id: uuid.UUID,
) -> WorkoutExercise:
    try:
        row = (
            _get_workout_exercise_for_user(
                db,
                user,
                workout_exercise_id,
            )
        )

        if row is None:
            raise WorkoutExerciseNotFoundError(
                "Workout exercise not found"
            )

        (
            workout_exercise,
            workout_session,
        ) = row

        if (
            workout_session.status
            != "in_progress"
        ):
            raise WorkoutNotInProgressError(
                "Workout is not in progress"
            )

        if (
            workout_exercise.status
            == "completed"
        ):
            raise (
                WorkoutExerciseAlreadyCompletedError(
                    "Completed exercise "
                    "cannot be skipped"
                )
            )

        workout_exercise.status = "skipped"

        db.commit()
        db.refresh(
            workout_exercise
        )

        return workout_exercise

    except Exception:
        db.rollback()
        raise


def get_workout_by_id(
    db: Session,
    user: User,
    workout_session_id: uuid.UUID,
) -> WorkoutSession | None:
    return db.scalar(
        select(
            WorkoutSession
        ).where(
            WorkoutSession.id
            == workout_session_id,
            WorkoutSession.user_id
            == user.id,
        )
    )


def get_workout_exercises(
    db: Session,
    workout_session_id: uuid.UUID,
):
    return db.scalars(
        select(
            WorkoutExercise
        )
        .where(
            WorkoutExercise.workout_session_id
            == workout_session_id
        )
        .order_by(
            WorkoutExercise.exercise_order
        )
    ).all()


def get_workout_sets(
    db: Session,
    workout_exercise_id: uuid.UUID,
):
    return db.scalars(
        select(
            WorkoutSet
        )
        .where(
            WorkoutSet.workout_exercise_id
            == workout_exercise_id
        )
        .order_by(
            WorkoutSet.set_number
        )
    ).all()


def get_user_workout_history(
    db: Session,
    user: User,
):
    return db.scalars(
        select(
            WorkoutSession
        )
        .where(
            WorkoutSession.user_id
            == user.id
        )
        .order_by(
            WorkoutSession.started_at.desc()
        )
    ).all()


def finish_workout(
    db: Session,
    user: User,
    workout_session_id: uuid.UUID,
) -> WorkoutSession:
    try:
        workout_session = db.scalar(
            select(
                WorkoutSession
            ).where(
                WorkoutSession.id
                == workout_session_id,
                WorkoutSession.user_id
                == user.id,
            )
        )

        if workout_session is None:
            raise WorkoutSessionNotFoundError(
                "Workout session not found"
            )

        if (
            workout_session.status
            != "in_progress"
        ):
            raise WorkoutNotInProgressError(
                "Workout is not in progress"
            )

        pending_count = db.scalar(
            select(
                func.count(
                    WorkoutExercise.id
                )
            ).where(
                WorkoutExercise.workout_session_id
                == workout_session.id,
                WorkoutExercise.status
                == "pending",
            )
        )

        pending_count = int(
            pending_count or 0
        )

        if pending_count > 0:
            raise WorkoutHasPendingExercisesError(
                f"Workout still has "
                f"{pending_count} pending "
                f"exercise(s). Complete or "
                f"skip them before finishing"
            )

        workout_session.status = (
            "completed"
        )

        workout_session.completed_at = (
            datetime.now(timezone.utc)
        )

        db.commit()
        db.refresh(
            workout_session
        )

        return workout_session

    except Exception:
        db.rollback()
        raise


def _get_workout_set_for_user(
    db: Session,
    user: User,
    workout_set_id: uuid.UUID,
):
    return db.execute(
        select(
            WorkoutSet,
            WorkoutExercise,
            WorkoutSession,
        )
        .join(
            WorkoutExercise,
            WorkoutSet.workout_exercise_id
            == WorkoutExercise.id,
        )
        .join(
            WorkoutSession,
            WorkoutExercise.workout_session_id
            == WorkoutSession.id,
        )
        .where(
            WorkoutSet.id == workout_set_id,
            WorkoutSession.user_id == user.id,
        )
    ).one_or_none()


def _validate_workout_set_values(
    actual_reps: int,
    weight_kg: Decimal | None,
    rpe: Decimal | None,
) -> None:
    if actual_reps < 0:
        raise WorkoutSetValidationError(
            "Actual reps cannot be negative"
        )

    if (
        weight_kg is not None
        and weight_kg < 0
    ):
        raise WorkoutSetValidationError(
            "Weight cannot be negative"
        )

    if (
        rpe is not None
        and not Decimal("1")
        <= rpe
        <= Decimal("10")
    ):
        raise WorkoutSetValidationError(
            "RPE must be between 1 and 10"
        )


def log_workout_set(
    db: Session,
    user: User,
    workout_set_id: uuid.UUID,
    actual_reps: int,
    weight_kg: Decimal | None = None,
    rpe: Decimal | None = None,
) -> WorkoutSet:
    try:
        row = _get_workout_set_for_user(
            db,
            user,
            workout_set_id,
        )

        if row is None:
            raise WorkoutSetNotFoundError(
                "Workout set not found"
            )

        (
            workout_set,
            workout_exercise,
            workout_session,
        ) = row

        if (
            workout_session.status
            != "in_progress"
        ):
            raise WorkoutNotInProgressError(
                "Workout is not in progress"
            )

        if (
            workout_exercise.status
            == "skipped"
        ):
            raise WorkoutExerciseSkippedError(
                "Cannot log a set for a "
                "skipped exercise"
            )

        _validate_workout_set_values(
            actual_reps=actual_reps,
            weight_kg=weight_kg,
            rpe=rpe,
        )

        workout_set.actual_reps = (
            actual_reps
        )
        workout_set.weight_kg = (
            weight_kg
        )
        workout_set.rpe = rpe
        workout_set.is_completed = True
        workout_set.completed_at = (
            datetime.now(timezone.utc)
        )

        db.flush()

        incomplete_sets = db.scalar(
            select(
                func.count(
                    WorkoutSet.id
                )
            )
            .where(
                WorkoutSet.workout_exercise_id
                == workout_exercise.id,
                WorkoutSet.is_completed
                .is_(False),
            )
        )

        if int(incomplete_sets or 0) == 0:
            workout_exercise.status = (
                "completed"
            )
        else:
            workout_exercise.status = (
                "pending"
            )

        db.commit()
        db.refresh(
            workout_set
        )

        return workout_set

    except Exception:
        db.rollback()
        raise