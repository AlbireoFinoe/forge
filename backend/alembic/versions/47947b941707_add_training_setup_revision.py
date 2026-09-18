"""add training setup revision

Revision ID: 47947b941707
Revises: 07586f4001f5
Create Date: 2026-09-18 14:59:13.847149

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '47947b941707'
down_revision: Union[str, Sequence[str], None] = '07586f4001f5'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        "training_programs",
        sa.Column(
            "setup_revision",
            sa.Integer(),
            server_default="1",
            nullable=False,
        ),
    )

    op.create_check_constraint(
        "ck_training_program_setup_revision",
        "training_programs",
        "setup_revision >= 1",
    )

    op.add_column(
        "users",
        sa.Column(
            "training_setup_revision",
            sa.Integer(),
            server_default="1",
            nullable=False,
        ),
    )

    op.create_check_constraint(
        "ck_users_training_setup_revision",
        "users",
        "training_setup_revision >= 1",
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_constraint(
        "ck_users_training_setup_revision",
        "users",
        type_="check",
    )

    op.drop_column(
        "users",
        "training_setup_revision",
    )

    op.drop_constraint(
        "ck_training_program_setup_revision",
        "training_programs",
        type_="check",
    )

    op.drop_column(
        "training_programs",
        "setup_revision",
    )
