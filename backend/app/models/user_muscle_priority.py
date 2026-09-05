import uuid

from sqlalchemy import (
    CheckConstraint,
    ForeignKey,
    String,
    UniqueConstraint,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class UserMusclePriority(Base):
    __tablename__ = "user_muscle_priorities"

    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "muscle_group_id",
            name="uq_user_muscle_priority",
        ),
        CheckConstraint(
            "priority IN ('high', 'normal', 'maintenance')",
            name="ck_user_muscle_priority_value",
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

    muscle_group_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey(
            "muscle_groups.id",
            ondelete="CASCADE",
        ),
        nullable=False,
    )

    priority: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
    )