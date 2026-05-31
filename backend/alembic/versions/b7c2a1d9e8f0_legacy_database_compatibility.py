"""attach legacy database revision to squashed history

Revision ID: b7c2a1d9e8f0
Revises: 906a00bf97dc
Create Date: 2026-05-31

Databases created before the migration history was squashed may still be
stamped with this revision. Keep it as a no-op alias so Alembic can resume
from that deployed state without replaying the initial schema DDL.
"""
from typing import Sequence, Union


revision: str = "b7c2a1d9e8f0"
down_revision: Union[str, None] = "906a00bf97dc"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
