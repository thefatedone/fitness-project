"""Idempotent saves for individual diary entries and photo recognition."""
from alembic import op
import sqlalchemy as sa
revision = "0006_save_operations"
down_revision = "0005_diary_deletions"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("save_operations",
        sa.Column("user_id", sa.String(), sa.ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("key", sa.String(), primary_key=True),
        sa.Column("route", sa.String(), nullable=False),
        sa.Column("fingerprint", sa.String(), nullable=False),
        sa.Column("response", sa.JSON(), nullable=True),
        sa.Column("resources", sa.JSON(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False))


def downgrade():
    op.drop_table("save_operations")
