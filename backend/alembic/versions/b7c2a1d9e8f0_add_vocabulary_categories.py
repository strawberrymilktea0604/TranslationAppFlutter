"""Add vocabulary categories to existing database

Revision ID: b7c2a1d9e8f0
Revises: a3f1c8e2d047
Create Date: 2026-05-19 04:47:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "b7c2a1d9e8f0"
down_revision: Union[str, None] = "a3f1c8e2d047"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "vocabulary_categories",
        sa.Column("id", sa.BigInteger(), autoincrement=False, nullable=False),
        sa.Column("user_id", sa.BigInteger(), nullable=False),
        sa.Column("name", sa.String(length=100), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=True,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=True,
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_vocabulary_categories_id"),
        "vocabulary_categories",
        ["id"],
        unique=False,
    )

    op.add_column(
        "vocabularies",
        sa.Column("category_id", sa.BigInteger(), nullable=True),
    )
    op.create_foreign_key(
        "fk_vocabularies_category_id_vocabulary_categories",
        "vocabularies",
        "vocabulary_categories",
        ["category_id"],
        ["id"],
        ondelete="RESTRICT",
    )


def downgrade() -> None:
    op.drop_constraint(
        "fk_vocabularies_category_id_vocabulary_categories",
        "vocabularies",
        type_="foreignkey",
    )
    op.drop_column("vocabularies", "category_id")
    op.drop_index(op.f("ix_vocabulary_categories_id"), table_name="vocabulary_categories")
    op.drop_table("vocabulary_categories")
