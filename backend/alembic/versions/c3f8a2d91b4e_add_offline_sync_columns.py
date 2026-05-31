"""add offline sync columns

Revision ID: c3f8a2d91b4e
Revises: d4e9f6a1b2c3
Create Date: 2026-05-31
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "c3f8a2d91b4e"
down_revision: Union[str, None] = "d4e9f6a1b2c3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("vocabularies", sa.Column("sync_client_id", sa.String(length=255), nullable=True))
    op.add_column("user_quizzes", sa.Column("sync_client_id", sa.String(length=255), nullable=True))

    op.create_index(
        "uq_vocabularies_user_sync_client_id",
        "vocabularies",
        ["user_id", "sync_client_id"],
        unique=True,
    )
    op.create_index(
        "uq_user_quizzes_user_sync_client_id",
        "user_quizzes",
        ["user_id", "sync_client_id"],
        unique=True,
    )
    op.create_index(
        "ix_vocabularies_user_updated_id",
        "vocabularies",
        ["user_id", "updated_at", "id"],
    )
    op.create_index(
        "ix_user_quizzes_user_updated_id",
        "user_quizzes",
        ["user_id", "updated_at", "id"],
    )


def downgrade() -> None:
    op.drop_index("ix_user_quizzes_user_updated_id", table_name="user_quizzes")
    op.drop_index("ix_vocabularies_user_updated_id", table_name="vocabularies")
    op.drop_index("uq_user_quizzes_user_sync_client_id", table_name="user_quizzes")
    op.drop_index("uq_vocabularies_user_sync_client_id", table_name="vocabularies")

    op.drop_column("user_quizzes", "sync_client_id")
    op.drop_column("vocabularies", "sync_client_id")
