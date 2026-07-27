"""add email verification fields

Revision ID: 917d929c55e1
Revises: 0001_add_password_reset_codes
Create Date: 2026-07-24 18:53:31.183657

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '917d929c55e1'
down_revision: Union[str, Sequence[str], None] = '0001_add_password_reset_codes'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # `is_email_verified` is `nullable=False` in the model (so every
    # existing row must have a value), but the model-level `default=False`
    # is a Python-side default — it doesn't help when this ALTER TABLE
    # runs against rows that already exist. We add a matching
    # `server_default` here so existing users all flip to
    # `is_email_verified=False` (their actual state — they haven't
    # verified yet) without Alembic choking on a NOT NULL violation.
    op.add_column(
        'users',
        sa.Column(
            'is_email_verified',
            sa.Boolean(),
            nullable=False,
            server_default=sa.text('false'),
        ),
    )
    op.add_column(
        'users',
        sa.Column('email_verification_code_hash', sa.String(), nullable=True),
    )
    op.add_column(
        'users',
        sa.Column('email_verification_expires_at', sa.DateTime(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column('users', 'email_verification_expires_at')
    op.drop_column('users', 'email_verification_code_hash')
    op.drop_column('users', 'is_email_verified')
