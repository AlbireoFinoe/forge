import uuid
from datetime import datetime

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Uuid,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class SportActivity(Base):
    __tablename__ = "sport_activities"

    __table_args__ = (
        CheckConstraint(
            "day_of_week BETWEEN 1 AND 7",
            name="ck_sport_activity_day",
        ),
        CheckConstraint(
            "duration_minutes BETWEEN 10 AND 300",
            name="ck_sport_activity_duration",
        ),
        CheckConstraint(
            "intensity IN ('low', 'moderate', 'high')",
            name="ck_sport_activity_intensity",
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

    sport_type: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
    )

    day_of_week: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    duration_minutes: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    intensity: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )