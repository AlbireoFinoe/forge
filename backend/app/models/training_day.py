import uuid

from sqlalchemy import (
    CheckConstraint,
    ForeignKey,
    Integer,
    UniqueConstraint,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class TrainingDay(Base):
    __tablename__ = "training_available_days"

    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "day_of_week",
            name="uq_training_day_user_day",
        ),
        CheckConstraint(
            "day_of_week BETWEEN 1 AND 7",
            name="ck_training_day_day_of_week",
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
        nullable=False,
    )

    day_of_week: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )