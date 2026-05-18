"""Legacy database state

Revision ID: a3f1c8e2d047
Revises:
Create Date: 2026-05-18 12:58:00.000000

This placeholder preserves the revision currently stored in local databases
created before the migration history was regenerated.
"""
from typing import Sequence, Union


revision: str = "a3f1c8e2d047"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
