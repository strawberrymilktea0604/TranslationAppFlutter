"""add conversation tables

Revision ID: e5a1b3c7d9f2
Revises: c3f8a2d91b4e
Create Date: 2026-05-31
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "e5a1b3c7d9f2"
down_revision: Union[str, None] = "c3f8a2d91b4e"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # --- conversation_sessions ---
    op.create_table(
        "conversation_sessions",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("session_uuid", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.BigInteger(), nullable=False),
        sa.Column("source_language", sa.String(length=10), nullable=False),
        sa.Column("target_language", sa.String(length=10), nullable=False),
        sa.Column(
            "status",
            sa.String(length=20),
            nullable=False,
            server_default="active",
        ),
        sa.Column(
            "started_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
        sa.Column("ended_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            ondelete="CASCADE",
        ),
    )
    op.create_index(
        "ix_conversation_sessions_session_uuid",
        "conversation_sessions",
        ["session_uuid"],
        unique=True,
    )
    op.create_index(
        "ix_conversation_sessions_user_id",
        "conversation_sessions",
        ["user_id"],
    )

    # --- conversation_messages ---
    op.create_table(
        "conversation_messages",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("session_id", sa.BigInteger(), nullable=False),
        sa.Column("sequence_number", sa.Integer(), nullable=False),
        sa.Column("speaker", sa.String(length=20), nullable=False),
        sa.Column("transcript", sa.Text(), nullable=False),
        sa.Column("translated_text", sa.Text(), nullable=False),
        sa.Column("source_language", sa.String(length=10), nullable=False),
        sa.Column("target_language", sa.String(length=10), nullable=False),
        sa.Column("stt_language", sa.String(length=10), nullable=True),
        sa.Column("stt_confidence", sa.Float(), nullable=True),
        sa.Column("finalize_trigger", sa.String(length=20), nullable=False),
        sa.Column("audio_size_bytes", sa.Integer(), nullable=True),
        sa.Column("audio_duration_ms", sa.Float(), nullable=True),
        sa.Column("is_cached", sa.Boolean(), server_default="false"),
        sa.Column("latency_stt_ms", sa.Float(), nullable=True),
        sa.Column("latency_translate_ms", sa.Float(), nullable=True),
        sa.Column("latency_persist_ms", sa.Float(), nullable=True),
        sa.Column("latency_total_ms", sa.Float(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(
            ["session_id"],
            ["conversation_sessions.id"],
            ondelete="CASCADE",
        ),
        sa.UniqueConstraint(
            "session_id",
            "sequence_number",
            name="uq_session_sequence",
        ),
    )


def downgrade() -> None:
    op.drop_table("conversation_messages")
    op.drop_table("conversation_sessions")
