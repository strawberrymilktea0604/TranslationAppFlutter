"""Add jti and indexes to user_tokens table

Revision ID: add_jti_to_user_tokens
Revises: 55f4e1e3280d
Create Date: 2026-04-15 10:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'add_jti_to_user_tokens'
down_revision = '55f4e1e3280d'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add jti column to user_tokens table
    op.add_column(
        'user_tokens',
        sa.Column('jti', sa.String(255), nullable=True)
    )
    
    # Create a default value for existing rows before making it not null
    op.execute("UPDATE user_tokens SET jti = gen_random_uuid()::text WHERE jti IS NULL")
    
    # Make jti NOT NULL and UNIQUE
    op.alter_column('user_tokens', 'jti', nullable=False)
    op.create_unique_constraint('uq_user_tokens_jti', 'user_tokens', ['jti'])
    
    # Create indexes for better query performance
    # Index for logout queries (find all tokens for a user)
    op.create_index(
        'ix_user_tokens_user_id_is_revoked',
        'user_tokens',
        ['user_id', 'is_revoked']
    )
    
    # Index for JTI lookups during revocation checks
    op.create_index(
        'ix_user_tokens_jti',
        'user_tokens',
        ['jti']
    )


def downgrade() -> None:
    # Remove indexes
    op.drop_index('ix_user_tokens_jti', table_name='user_tokens')
    op.drop_index('ix_user_tokens_user_id_is_revoked', table_name='user_tokens')
    
    # Remove unique constraint
    op.drop_constraint('uq_user_tokens_jti', 'user_tokens', type_='unique')
    
    # Remove jti column
    op.drop_column('user_tokens', 'jti')
