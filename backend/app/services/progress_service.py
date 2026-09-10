import uuid
from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.user import User
from app.models.workout_exercise import WorkoutExercise
from app.models.workout_session import WorkoutSession
from app.models.workout_set import WorkoutSet


class ProgressError(Exception):
    pass


class WorkoutProgressNotFoundError(ProgressError):
    pass


class ExerciseHistoryNotFoundError(ProgressError):
    pass


@dataclass(frozen=True)
class WorkoutProgressSummary:
    workout_id: uuid.UUID

    program_version_number: int
    day_name: str
    status: str

    started_at: datetime
    completed_at: datetime | None

    duration_minutes: float | None

    total_exercises: int
    completed_exercises: int
    skipped_exercises: int

    planned_sets: int
    completed_sets: int
    set_completion_rate: float

    total_reps: int

    external_volume_kg: Decimal
    average_rpe: Decimal | None


@dataclass(frozen=True)
class ExerciseWorkoutHistoryItem:
    workout_id: uuid.UUID
    workout_completed_at: datetime

    exercise_code: str
    exercise_name: str
    exercise_status: str

    target_sets: int
    completed_sets: int
    set_completion_rate: float

    total_reps: int

    top_weight_kg: Decimal | None
    external_volume_kg: Decimal

    average_rpe: Decimal | None


@dataclass(frozen=True)
class ExerciseProgressAnalysis:
    exercise_code: str
    exercise_name: str

    history_entries: int
    completed_sessions: int

    best_weight_kg: Decimal | None
    best_weight_reps: int | None

    best_session_volume_kg: Decimal

    latest_top_weight_kg: Decimal | None
    latest_volume_kg: Decimal | None
    latest_average_rpe: Decimal | None

    previous_top_weight_kg: Decimal | None
    previous_volume_kg: Decimal | None
    previous_average_rpe: Decimal | None

    volume_change_percent: float | None
    trend: str

def get_workout_progress_summary(
    db: Session,
    user: User,
    workout_session_id: uuid.UUID,
) -> WorkoutProgressSummary:

    workout = db.scalar(
        select(
            WorkoutSession
        ).where(
            WorkoutSession.id
            == workout_session_id,
            WorkoutSession.user_id
            == user.id,
        )
    )

    if workout is None:
        raise WorkoutProgressNotFoundError(
            "Workout not found"
        )

    exercises = db.scalars(
        select(
            WorkoutExercise
        ).where(
            WorkoutExercise.workout_session_id
            == workout.id
        )
    ).all()

    workout_sets = db.scalars(
        select(
            WorkoutSet
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
    ).all()

    completed_sets = [
        workout_set
        for workout_set in workout_sets
        if workout_set.is_completed
    ]

    total_exercises = len(
        exercises
    )

    completed_exercises = sum(
        1
        for exercise in exercises
        if exercise.status == "completed"
    )

    skipped_exercises = sum(
        1
        for exercise in exercises
        if exercise.status == "skipped"
    )

    planned_sets = len(
        workout_sets
    )

    completed_set_count = len(
        completed_sets
    )

    if planned_sets > 0:
        set_completion_rate = round(
            (
                completed_set_count
                / planned_sets
            )
            * 100,
            1,
        )
    else:
        set_completion_rate = 0.0

    total_reps = sum(
        workout_set.actual_reps or 0
        for workout_set in completed_sets
    )

    external_volume_kg = sum(
        (
            Decimal(
                workout_set.actual_reps
            )
            * workout_set.weight_kg
        )
        for workout_set in completed_sets
        if (
            workout_set.actual_reps
            is not None
            and workout_set.weight_kg
            is not None
        )
    ) if completed_sets else Decimal("0")

    rpe_values = [
        workout_set.rpe
        for workout_set in completed_sets
        if workout_set.rpe is not None
    ]

    if rpe_values:
        average_rpe = (
            sum(
                rpe_values,
                Decimal("0"),
            )
            / Decimal(
                len(rpe_values)
            )
        ).quantize(
            Decimal("0.1")
        )
    else:
        average_rpe = None

    duration_minutes = None

    if workout.completed_at is not None:
        duration_minutes = round(
            (
                workout.completed_at
                - workout.started_at
            ).total_seconds()
            / 60,
            1,
        )

    return WorkoutProgressSummary(
        workout_id=workout.id,
        program_version_number=(
            workout.program_version_number
        ),
        day_name=workout.day_name,
        status=workout.status,
        started_at=workout.started_at,
        completed_at=workout.completed_at,
        duration_minutes=(
            duration_minutes
        ),
        total_exercises=(
            total_exercises
        ),
        completed_exercises=(
            completed_exercises
        ),
        skipped_exercises=(
            skipped_exercises
        ),
        planned_sets=planned_sets,
        completed_sets=(
            completed_set_count
        ),
        set_completion_rate=(
            set_completion_rate
        ),
        total_reps=total_reps,
        external_volume_kg=(
            external_volume_kg
        ),
        average_rpe=average_rpe,
    )


def get_exercise_history(
    db: Session,
    user: User,
    exercise_code: str,
    limit: int = 20,
) -> list[ExerciseWorkoutHistoryItem]:

    rows = db.execute(
        select(
            WorkoutExercise,
            WorkoutSession,
        )
        .join(
            WorkoutSession,
            WorkoutExercise.workout_session_id
            == WorkoutSession.id,
        )
        .join(
            WorkoutSet,
            WorkoutSet.workout_exercise_id
            == WorkoutExercise.id,
        )
        .where(
            WorkoutSession.user_id
            == user.id,
            WorkoutSession.status
            == "completed",
            WorkoutExercise.exercise_code
            == exercise_code,
            WorkoutSet.is_completed
            .is_(True),
        )
        .distinct()
        .order_by(
            WorkoutSession.completed_at.desc()
        )
        .limit(limit)
    ).all()

    history = []

    for exercise, workout in rows:
        completed_sets = db.scalars(
            select(
                WorkoutSet
            )
            .where(
                WorkoutSet.workout_exercise_id
                == exercise.id,
                WorkoutSet.is_completed
                .is_(True),
            )
            .order_by(
                WorkoutSet.set_number
            )
        ).all()

        if not completed_sets:
            continue

        completed_set_count = len(
            completed_sets
        )

        if exercise.target_sets > 0:
            set_completion_rate = round(
                (
                    completed_set_count
                    / exercise.target_sets
                )
                * 100,
                1,
            )
        else:
            set_completion_rate = 0.0

        total_reps = sum(
            workout_set.actual_reps or 0
            for workout_set in completed_sets
        )

        weighted_sets = [
            workout_set
            for workout_set in completed_sets
            if (
                workout_set.weight_kg
                is not None
                and workout_set.actual_reps
                is not None
            )
        ]

        if weighted_sets:
            top_weight_kg = max(
                workout_set.weight_kg
                for workout_set
                in weighted_sets
            )

            external_volume_kg = sum(
                (
                    Decimal(
                        workout_set.actual_reps
                    )
                    * workout_set.weight_kg
                )
                for workout_set
                in weighted_sets
            )
        else:
            top_weight_kg = None
            external_volume_kg = (
                Decimal("0")
            )

        rpe_values = [
            workout_set.rpe
            for workout_set in completed_sets
            if workout_set.rpe is not None
        ]

        if rpe_values:
            average_rpe = (
                sum(
                    rpe_values,
                    Decimal("0"),
                )
                / Decimal(len(rpe_values))
            ).quantize(
                Decimal("0.1")
            )
        else:
            average_rpe = None

        if workout.completed_at is None:
            continue

        history.append(
            ExerciseWorkoutHistoryItem(
                workout_id=workout.id,
                workout_completed_at=(
                    workout.completed_at
                ),
                exercise_code=(
                    exercise.exercise_code
                ),
                exercise_name=(
                    exercise.exercise_name
                ),
                exercise_status=(
                    exercise.status
                ),
                target_sets=(
                    exercise.target_sets
                ),
                completed_sets=(
                    completed_set_count
                ),
                set_completion_rate=(
                    set_completion_rate
                ),
                total_reps=total_reps,
                top_weight_kg=(
                    top_weight_kg
                ),
                external_volume_kg=(
                    external_volume_kg
                ),
                average_rpe=average_rpe,
            )
        )

    return history


def get_exercise_progress_analysis(
    db: Session,
    user: User,
    exercise_code: str,
) -> ExerciseProgressAnalysis:

    history = get_exercise_history(
        db=db,
        user=user,
        exercise_code=exercise_code,
        limit=100,
    )

    if not history:
        raise ExerciseHistoryNotFoundError(
            "No exercise history found"
        )

    exercise_name = (
        history[0].exercise_name
    )

    completed_sessions = [
        item
        for item in history
        if item.exercise_status == "completed"
    ]

    best_session_volume_kg = max(
        (
            item.external_volume_kg
            for item in completed_sessions
        ),
        default=Decimal("0"),
    )

    best_set_row = db.execute(
        select(
            WorkoutSet.weight_kg,
            WorkoutSet.actual_reps,
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
            WorkoutSession.user_id
            == user.id,
            WorkoutSession.status
            == "completed",
            WorkoutExercise.exercise_code
            == exercise_code,
            WorkoutSet.is_completed
            .is_(True),
            WorkoutSet.weight_kg
            .is_not(None),
        )
        .order_by(
            WorkoutSet.weight_kg.desc(),
            WorkoutSet.actual_reps.desc(),
        )
        .limit(1)
    ).one_or_none()

    if best_set_row is not None:
        (
            best_weight_kg,
            best_weight_reps,
        ) = best_set_row
    else:
        best_weight_kg = None
        best_weight_reps = None

    latest = (
        completed_sessions[0]
        if completed_sessions
        else None
    )

    previous = (
        completed_sessions[1]
        if len(completed_sessions) >= 2
        else None
    )

    volume_change_percent = None
    trend = "insufficient_data"

    if (
        latest is not None
        and previous is not None
    ):
        if (
            previous.external_volume_kg
            > 0
        ):
            volume_change_percent = round(
                (
                    (
                        latest.external_volume_kg
                        - previous.external_volume_kg
                    )
                    / previous.external_volume_kg
                )
                * 100,
                1,
            )

            if volume_change_percent > 5:
                trend = "improving"
            elif volume_change_percent < -5:
                trend = "declining"
            else:
                trend = "stable"

    return ExerciseProgressAnalysis(
        exercise_code=exercise_code,
        exercise_name=exercise_name,
        history_entries=len(
            history
        ),
        completed_sessions=len(
            completed_sessions
        ),
        best_weight_kg=(
            best_weight_kg
        ),
        best_weight_reps=(
            best_weight_reps
        ),
        best_session_volume_kg=(
            best_session_volume_kg
        ),
        latest_top_weight_kg=(
            latest.top_weight_kg
            if latest is not None
            else None
        ),
        latest_volume_kg=(
            latest.external_volume_kg
            if latest is not None
            else None
        ),
        latest_average_rpe=(
            latest.average_rpe
            if latest is not None
            else None
        ),
        previous_top_weight_kg=(
            previous.top_weight_kg
            if previous is not None
            else None
        ),
        previous_volume_kg=(
            previous.external_volume_kg
            if previous is not None
            else None
        ),
        previous_average_rpe=(
            previous.average_rpe
            if previous is not None
            else None
        ),
        volume_change_percent=(
            volume_change_percent
        ),
        trend=trend,
    )