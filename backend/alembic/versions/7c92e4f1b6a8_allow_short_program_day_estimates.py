"""allow short program day estimates

Revision ID: 7c92e4f1b6a8
Revises: a4f6c91d2e7b
Create Date: 2026-11-19

"""
from typing import Sequence, Union

from alembic import op


revision: str = "7c92e4f1b6a8"
down_revision: Union[str, Sequence[str], None] = "a4f6c91d2e7b"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

CONSTRAINT_NAME = "ck_program_day_duration"
TABLE_NAME = "program_days"


def upgrade() -> None:
    op.drop_constraint(CONSTRAINT_NAME, TABLE_NAME, type_="check")
    op.create_check_constraint(
        CONSTRAINT_NAME,
        TABLE_NAME,
        "estimated_duration_minutes BETWEEN 1 AND 240",
    )


def downgrade() -> None:
    # PostgreSQL rejects the stricter check if short estimates still exist.
    op.drop_constraint(CONSTRAINT_NAME, TABLE_NAME, type_="check")
    op.create_check_constraint(
        CONSTRAINT_NAME,
        TABLE_NAME,
        "estimated_duration_minutes BETWEEN 15 AND 240",
    )
