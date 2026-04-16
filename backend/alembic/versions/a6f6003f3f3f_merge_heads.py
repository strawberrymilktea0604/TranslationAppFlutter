"""Merge heads

Revision ID: a6f6003f3f3f
Revises: 2985dfea2cd0, add_jti_to_user_tokens
Create Date: 2026-04-16 07:10:25.340195

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa



# revision identifiers, used by Alembic.
revision: str = 'a6f6003f3f3f'
down_revision: Union[str, None] = ('2985dfea2cd0', 'add_jti_to_user_tokens')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
