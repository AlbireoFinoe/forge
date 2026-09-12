"""add sports setup status

Revision ID: 07586f4001f5
Revises: e1a7c9b4d2f0
Create Date: 2026-09-12 13:52:13.620355

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '07586f4001f5'
down_revision: Union[str, Sequence[str], None] = 'e1a7c9b4d2f0'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Backfill sports setup status for existing users."""
    op.execute(
        sa.text(
            """
            UPDATE training_preferences AS tp
            SET sports_configured = true
            WHERE EXISTS (
                SELECT 1
                FROM sport_activities AS sa
                WHERE sa.user_id = tp.user_id
            )
            """
        )
    )


def downgrade() -> None:
    """Reverse the sports setup backfill."""
    op.execute(
        sa.text(
            """
            UPDATE training_preferences AS tp
            SET sports_configured = false
            WHERE EXISTS (
                SELECT 1
                FROM sport_activities AS sa
                WHERE sa.user_id = tp.user_id
            )
            """
        )
    )
