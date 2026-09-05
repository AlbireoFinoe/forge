import uuid

from sqlalchemy import (
    CheckConstraint,
    ForeignKey,
    Integer,
    JSON,
    UniqueConstraint,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class ProgramExercise(Base):
    __tablename__ = "program_exercises"

    __table_args__ = (
        UniqueConstraint(
            "program_day_id",
            "exercise_order",
            name="uq_program_exercise_order",
        ),
        UniqueConstraint(
            "program_day_id",
            "exercise_id",
            name="uq_program_day_exercise",
        ),
        CheckConstraint(
            "exercise_order >= 1",
            name="ck_program_exercise_order",
        ),
        CheckConstraint(
            "sets BETWEEN 1 AND 10",
            name="ck_program_exercise_sets",
        ),
        CheckConstraint(
            "min_reps >= 1",
            name="ck_program_exercise_min_reps",
        ),
        CheckConstraint(
            "max_reps >= min_reps",
            name="ck_program_exercise_rep_range",
        ),
        CheckConstraint(
            "rest_seconds BETWEEN 15 AND 600",
            name="ck_program_exercise_rest",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )

    program_day_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey(
            "program_days.id",
            ondelete="CASCADE",
        ),
        nullable=False,
    )

    exercise_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey(
            "exercises.id",
            ondelete="RESTRICT",
        ),
        nullable=False,
    )

    exercise_order: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    sets: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    min_reps: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    max_reps: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    rest_seconds: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    reason_codes: Mapped[list[str]] = mapped_column(
        JSON,
        default=list,
        nullable=False,
    )