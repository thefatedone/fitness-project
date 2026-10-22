"""Persist earned garden days independently of editable diary rows."""
from alembic import op
import sqlalchemy as sa

revision = "0003_garden_days"
down_revision = "0002_add_auth_identities"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("garden_days",
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("day", sa.Date(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("user_id", "day"))


def downgrade():
    op.drop_table("garden_days")
