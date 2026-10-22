"""Reversible, idempotent diary deletion receipts."""
from alembic import op
import sqlalchemy as sa

revision = "0005_diary_deletions"
down_revision = "0004_saved_meals"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("diary_deletions",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("user_id", sa.String(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("selection", sa.JSON(), nullable=False),
        sa.Column("snapshot", sa.JSON(), nullable=False),
        sa.Column("state", sa.String(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False))
    op.create_index("ix_diary_deletions_user_id", "diary_deletions", ["user_id"])


def downgrade():
    op.drop_index("ix_diary_deletions_user_id", table_name="diary_deletions")
    op.drop_table("diary_deletions")
