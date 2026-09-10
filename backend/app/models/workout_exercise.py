import uuid

from sqlalchemy import (
    CheckConstraint,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class WorkoutExercise(Base):
    __tablename__ = "workout_exercises"

    __table_args__ = (
        UniqueConstraint(
            "workout_session_id",
            "exercise_order",
            name="uq_workout_exercise_order",
        ),
        CheckConstraint(
            "exercise_order >= 1",
            name="ck_workout_exercise_order",
        ),
        CheckConstraint(
            "target_sets BETWEEN 1 AND 10",
            name="ck_workout_exercise_target_sets",
        ),
        CheckConstraint(
            "target_min_reps >= 1",
            name="ck_workout_exercise_min_reps",
        ),
        CheckConstraint(
            "target_max_reps >= target_min_reps",
            name="ck_workout_exercise_rep_range",
        ),
        CheckConstraint(
            "target_rest_seconds BETWEEN 15 AND 600",
            name="ck_workout_exercise_rest",
        ),
        CheckConstraint(
            "status IN ('pending', 'completed', 'skipped')",
            name="ck_workout_exercise_status",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )

    workout_session_id: Mapped[
        uuid.UUID
    ] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey(
            "workout_sessions.id",
            ondelete="CASCADE",
        ),
        nullable=False,
    )

    program_exercise_id: Mapped[
        uuid.UUID | None
    ] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey(
            "program_exercises.id",
            ondelete="SET NULL",
        ),
        nullable=True,
    )

    exercise_id: Mapped[
        uuid.UUID | None
    ] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey(
            "exercises.id",
            ondelete="SET NULL",
        ),
        nullable=True,
    )

    exercise_code: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )

    exercise_name: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
    )

    exercise_order: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    target_sets: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    target_min_reps: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    target_max_reps: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    target_rest_seconds: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    status: Mapped[str] = mapped_column(
        String(20),
        default="pending",
        nullable=False,
    )

    notes: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )