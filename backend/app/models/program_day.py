import uuid

from sqlalchemy import (
    CheckConstraint,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class ProgramDay(Base):
    __tablename__ = "program_days"

    __table_args__ = (
        UniqueConstraint(
            "program_id",
            "day_order",
            name="uq_program_day_order",
        ),
        UniqueConstraint(
            "program_id",
            "day_of_week",
            name="uq_program_day_weekday",
        ),
        CheckConstraint(
            "day_of_week BETWEEN 1 AND 7",
            name="ck_program_day_weekday",
        ),
        CheckConstraint(
            "day_order BETWEEN 1 AND 7",
            name="ck_program_day_order",
        ),
        CheckConstraint(
            "estimated_duration_minutes BETWEEN 15 AND 240",
            name="ck_program_day_duration",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )

    program_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey(
            "training_programs.id",
            ondelete="CASCADE",
        ),
        nullable=False,
    )

    day_of_week: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    day_order: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    name: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
    )

    estimated_duration_minutes: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )