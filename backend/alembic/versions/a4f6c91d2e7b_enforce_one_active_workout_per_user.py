"""enforce one active workout per user

Revision ID: a4f6c91d2e7b
Revises: ff4d2216b3e0
Create Date: 2026-11-09

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "a4f6c91d2e7b"
down_revision: Union[str, Sequence[str], None] = "ff4d2216b3e0"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

INDEX_NAME = "uq_workout_sessions_one_active_per_user"


def _check_for_duplicate_active_workouts(connection) -> None:
    duplicate_user_count = connection.execute(
        sa.text(
            """
            SELECT COUNT(*)
            FROM (
                SELECT user_id
                FROM workout_sessions
                WHERE status = 'in_progress'
                GROUP BY user_id
                HAVING COUNT(*) > 1
            ) AS duplicate_users
            """
        )
    ).scalar_one()

    if duplicate_user_count:
        raise RuntimeError(
            "Cannot create "
            f"{INDEX_NAME}: "
            f"{duplicate_user_count} user(s) have multiple "
            "in-progress workouts. Resolve the duplicates "
            "manually and retry the migration; no data was "
            "deleted."
        )


def upgrade() -> None:
    connection = op.get_bind()
    if connection.dialect.name != "postgresql":
        raise RuntimeError(
            "The active workout index migration "
            "requires PostgreSQL."
        )

    _check_for_duplicate_active_workouts(connection)

    op.create_index(
        INDEX_NAME,
        "workout_sessions",
        ["user_id"],
        unique=True,
        postgresql_where=sa.text(
            "status = 'in_progress'"
        ),
    )


def downgrade() -> None:
    op.drop_index(
        INDEX_NAME,
        table_name="workout_sessions",
    )
