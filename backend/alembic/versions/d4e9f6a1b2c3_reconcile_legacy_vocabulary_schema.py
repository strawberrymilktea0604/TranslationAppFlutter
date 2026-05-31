"""reconcile legacy vocabulary schema

Revision ID: d4e9f6a1b2c3
Revises: b7c2a1d9e8f0
Create Date: 2026-05-31
"""
from typing import Sequence, Union

from alembic import op


revision: str = "d4e9f6a1b2c3"
down_revision: Union[str, None] = "b7c2a1d9e8f0"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Fresh databases already have these columns from the squashed initial
    # migration. Older deployed databases need them before offline sync starts.
    op.execute("ALTER TABLE vocabularies ADD COLUMN IF NOT EXISTS category VARCHAR(100)")
    op.execute("ALTER TABLE vocabularies ADD COLUMN IF NOT EXISTS word TEXT")
    op.execute("ALTER TABLE vocabularies ADD COLUMN IF NOT EXISTS definition TEXT")
    op.execute("ALTER TABLE vocabularies ADD COLUMN IF NOT EXISTS source_language VARCHAR(50)")
    op.execute("ALTER TABLE vocabularies ADD COLUMN IF NOT EXISTS target_language VARCHAR(50)")

    op.execute(
        """
        UPDATE vocabularies AS vocabulary
        SET word = COALESCE(vocabulary.word, translation.source_text),
            definition = COALESCE(vocabulary.definition, translation.translated_text),
            source_language = COALESCE(vocabulary.source_language, translation.source_language),
            target_language = COALESCE(vocabulary.target_language, translation.target_language)
        FROM translations AS translation
        WHERE vocabulary.translation_id = translation.id
        """
    )
    op.execute(
        """
        UPDATE vocabularies AS vocabulary
        SET category = COALESCE(vocabulary.category, category.name)
        FROM vocabulary_categories AS category
        WHERE vocabulary.category_id = category.id
        """
    )


def downgrade() -> None:
    # These columns are part of the squashed baseline schema. Removing them
    # would break fresh databases when downgrading across the compatibility step.
    pass
