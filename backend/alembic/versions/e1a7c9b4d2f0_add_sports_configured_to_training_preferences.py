"""add sports configured to training preferences

Revision ID: e1a7c9b4d2f0
Revises: dcf4a6e72640
Create Date: 2026-09-12 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e1a7c9b4d2f0'
down_revision: Union[str, Sequence[str], None] = 'dcf4a6e72640'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        'training_preferences',
        sa.Column(
            'sports_configured',
            sa.Boolean(),
            server_default=sa.text('false'),
            nullable=False,
        ),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column(
        'training_preferences',
        'sports_configured',
    )
