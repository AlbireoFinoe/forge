import uuid
from datetime import datetime

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
    Uuid,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class TrainingProgram(Base):
    __tablename__ = "training_programs"

    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "version_number",
            name="uq_training_program_user_version",
        ),
        CheckConstraint(
            "version_number >= 1",
            name="ck_training_program_version",
        ),
        CheckConstraint(
            "setup_revision >= 1",
            name="ck_training_program_setup_revision",
        ),
        CheckConstraint(
            "status IN ('draft', 'active', 'archived')",
            name="ck_training_program_status",
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

    name: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
    )

    goal: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
    )

    generator_version: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
    )

    version_number: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    setup_revision: Mapped[int] = mapped_column(
        Integer,
        default=1,
        server_default="1",
        nullable=False,
    )

    status: Mapped[str] = mapped_column(
        String(20),
        default="draft",
        nullable=False,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )