import uuid
from decimal import Decimal

from sqlalchemy import (
    CheckConstraint,
    ForeignKey,
    Numeric,
    UniqueConstraint,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class UserLoadPreference(Base):
    __tablename__ = "user_load_preferences"

    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "equipment_id",
            name="uq_user_load_preference_equipment",
        ),
        CheckConstraint(
            "increment_kg > 0",
            name="ck_user_load_preference_increment_positive",
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

    equipment_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey(
            "equipment.id",
            ondelete="CASCADE",
        ),
        nullable=False,
    )

    increment_kg: Mapped[Decimal] = mapped_column(
        Numeric(
            precision=6,
            scale=2,
        ),
        nullable=False,
    )
