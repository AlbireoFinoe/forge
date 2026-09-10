import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    UniqueConstraint,
    Uuid,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class WorkoutSet(Base):
    __tablename__ = "workout_sets"

    __table_args__ = (
        UniqueConstraint(
            "workout_exercise_id",
            "set_number",
            name="uq_workout_set_number",
        ),
        CheckConstraint(
            "set_number >= 1",
            name="ck_workout_set_number",
        ),
        CheckConstraint(
            "actual_reps >= 0",
            name="ck_workout_set_reps",
        ),
        CheckConstraint(
            "weight_kg >= 0",
            name="ck_workout_set_weight",
        ),
        CheckConstraint(
            "rpe BETWEEN 1 AND 10",
            name="ck_workout_set_rpe",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )

    workout_exercise_id: Mapped[
        uuid.UUID
    ] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey(
            "workout_exercises.id",
            ondelete="CASCADE",
        ),
        nullable=False,
    )

    set_number: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    actual_reps: Mapped[
        int | None
    ] = mapped_column(
        Integer,
        nullable=True,
    )

    weight_kg: Mapped[
        Decimal | None
    ] = mapped_column(
        Numeric(
            precision=7,
            scale=2,
        ),
        nullable=True,
    )

    rpe: Mapped[
        Decimal | None
    ] = mapped_column(
        Numeric(
            precision=3,
            scale=1,
        ),
        nullable=True,
    )

    is_completed: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )

    completed_at: Mapped[
        datetime | None
    ] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )