"""Add quiz attempt fields to user_quizzes

Revision ID: a3f1c8e2d047
Revises: b98bd268c329
Create Date: 2026-05-18 12:58:00.000000

Adds time_spent_seconds, total_questions, correct_answers, submitted_at
to user_quizzes while keeping completion_time_seconds for backward compat.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a3f1c8e2d047'
down_revision: Union[str, None] = 'b98bd268c329'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add new timing / count / submission fields to user_quizzes.
    # completion_time_seconds is retained for backward compatibility.
    op.add_column(
        'user_quizzes',
        sa.Column('time_spent_seconds', sa.Integer(), nullable=True),
    )
    op.add_column(
        'user_quizzes',
        sa.Column('total_questions', sa.Integer(), nullable=True),
    )
    op.add_column(
        'user_quizzes',
        sa.Column('correct_answers', sa.Integer(), nullable=True),
    )
    op.add_column(
        'user_quizzes',
        sa.Column('submitted_at', sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_column('user_quizzes', 'submitted_at')
    op.drop_column('user_quizzes', 'correct_answers')
    op.drop_column('user_quizzes', 'total_questions')
    op.drop_column('user_quizzes', 'time_spent_seconds')
