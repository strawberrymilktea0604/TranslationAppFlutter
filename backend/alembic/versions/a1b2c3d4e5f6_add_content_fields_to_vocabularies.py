"""add_content_fields_to_vocabularies

Adds denormalized content columns directly to the vocabularies table
so queries can read word/definition/language without a JOIN.

New columns:
  - word          TEXT  (= translations.source_text)
  - definition    TEXT  (= translations.translated_text)
  - source_language  VARCHAR(50)
  - target_language  VARCHAR(50)

After adding the columns, a SQL backfill copies data from the
translations table for all existing vocabulary rows.

Revision ID: a1b2c3d4e5f6
Revises: 81a695072321
Create Date: 2026-05-21 13:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = 'a1b2c3d4e5f6'
down_revision: Union[str, None] = '81a695072321'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Add new columns (nullable so existing rows don't break)
    op.add_column('vocabularies',
        sa.Column('word', sa.Text(), nullable=True))
    op.add_column('vocabularies',
        sa.Column('definition', sa.Text(), nullable=True))
    op.add_column('vocabularies',
        sa.Column('source_language', sa.String(length=50), nullable=True))
    op.add_column('vocabularies',
        sa.Column('target_language', sa.String(length=50), nullable=True))

    # 2. Backfill existing rows from the translations table
    op.execute("""
        UPDATE vocabularies v
        SET
            word            = t.source_text,
            definition      = t.translated_text,
            source_language = t.source_language,
            target_language = t.target_language
        FROM translations t
        WHERE v.translation_id = t.id
    """)


def downgrade() -> None:
    op.drop_column('vocabularies', 'target_language')
    op.drop_column('vocabularies', 'source_language')
    op.drop_column('vocabularies', 'definition')
    op.drop_column('vocabularies', 'word')
