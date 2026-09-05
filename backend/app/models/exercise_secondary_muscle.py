import uuid

from sqlalchemy import (
    CheckConstraint,
    Float,
    ForeignKey,
    UniqueConstraint,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class ExerciseSecondaryMuscle(Base):
    __tablename__ = "exercise_secondary_muscles"

    __table_args__ = (
        UniqueConstraint(
            "exercise_id",
            "muscle_group_id",
            name="uq_exercise_secondary_muscle",
        ),
        CheckConstraint(
            "contribution_weight > 0 AND contribution_weight <= 1",
            name="ck_secondary_muscle_contribution",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )

    exercise_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey(
            "exercises.id",
            ondelete="CASCADE",
        ),
        nullable=False,
    )

    muscle_group_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey(
            "muscle_groups.id",
            ondelete="RESTRICT",
        ),
        nullable=False,
    )

    contribution_weight: Mapped[float] = mapped_column(
        Float,
        default=0.5,
        nullable=False,
    )