import uuid

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    ForeignKey,
    Integer,
    String,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class Exercise(Base):
    __tablename__ = "exercises"

    __table_args__ = (
        CheckConstraint(
            "default_min_reps >= 1",
            name="ck_exercise_min_reps",
        ),
        CheckConstraint(
            "default_max_reps >= default_min_reps",
            name="ck_exercise_rep_range",
        ),
        CheckConstraint(
            "default_rest_seconds BETWEEN 15 AND 600",
            name="ck_exercise_rest_seconds",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )

    code: Mapped[str] = mapped_column(
        String(100),
        unique=True,
        nullable=False,
    )

    name: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
    )

    primary_muscle_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey(
            "muscle_groups.id",
            ondelete="RESTRICT",
        ),
        nullable=False,
    )

    movement_pattern: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
    )

    difficulty: Mapped[str] = mapped_column(
        String(30),
        default="intermediate",
        nullable=False,
    )

    is_compound: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
    )

    default_min_reps: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    default_max_reps: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    default_rest_seconds: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
    )