import uuid
from datetime import datetime

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    Uuid,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class WorkoutSession(Base):
    __tablename__ = "workout_sessions"

    __table_args__ = (
        CheckConstraint(
            "status IN ('in_progress', 'completed', 'cancelled')",
            name="ck_workout_session_status",
        ),
        CheckConstraint(
            "program_version_number >= 1",
            name="ck_workout_session_program_version",
        ),
        CheckConstraint(
            "day_of_week BETWEEN 1 AND 7",
            name="ck_workout_session_weekday",
        ),
        CheckConstraint(
            "day_order BETWEEN 1 AND 7",
            name="ck_workout_session_day_order",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey(
            "users.id",
            ondelete="CASCADE",
        ),
        nullable=False,
    )

    training_program_id: Mapped[
        uuid.UUID | None
    ] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey(
            "training_programs.id",
            ondelete="SET NULL",
        ),
        nullable=True,
    )

    program_day_id: Mapped[
        uuid.UUID | None
    ] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey(
            "program_days.id",
            ondelete="SET NULL",
        ),
        nullable=True,
    )

    program_version_number: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    program_name: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
    )

    day_name: Mapped[str] = mapped_column(
        String(150),
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

    status: Mapped[str] = mapped_column(
        String(20),
        default="in_progress",
        nullable=False,
    )

    notes: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )

    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
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