import uuid

from sqlalchemy import (
    ForeignKey,
    UniqueConstraint,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class ExerciseEquipment(Base):
    __tablename__ = "exercise_equipment"

    __table_args__ = (
        UniqueConstraint(
            "exercise_id",
            "equipment_id",
            name="uq_exercise_equipment",
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

    equipment_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey(
            "equipment.id",
            ondelete="RESTRICT",
        ),
        nullable=False,
    )