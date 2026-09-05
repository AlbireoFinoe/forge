import uuid

from sqlalchemy import (
    ForeignKey,
    UniqueConstraint,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class UserEquipment(Base):
    __tablename__ = "user_equipment"

    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "equipment_id",
            name="uq_user_equipment",
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