import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Integer,
    Uuid,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class TrainingPreference(Base):
    __tablename__ = "training_preferences"

    __table_args__ = (
        CheckConstraint(
            "days_per_week BETWEEN 1 AND 7",
            name="ck_training_preferences_days_per_week",
        ),
        CheckConstraint(
            "session_duration_minutes BETWEEN 15 AND 240",
            name="ck_training_preferences_session_duration",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )

    days_per_week: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    session_duration_minutes: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    no_dedicated_leg_day: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )

    arm_specialization: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )

    sports_configured: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        server_default="false",
        nullable=False,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )