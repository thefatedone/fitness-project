"""Save a dish atomically and retain its ingredients for repeat logging."""
from alembic import op
import sqlalchemy as sa

revision = "0004_saved_meals"
down_revision = "0003_garden_days"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("saved_meals",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("user_id", sa.String(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("payload", sa.JSON(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False))
    op.create_index("ix_saved_meals_user_id", "saved_meals", ["user_id"])
    op.add_column("food_logs", sa.Column("meal_id", sa.String(), nullable=True))
    op.add_column("food_logs", sa.Column("meal_name", sa.String(), nullable=True))
    op.create_foreign_key("fk_food_logs_saved_meal", "food_logs", "saved_meals", ["meal_id"], ["id"], ondelete="SET NULL")
    op.create_index("ix_food_logs_meal_id", "food_logs", ["meal_id"])


def downgrade():
    op.drop_index("ix_food_logs_meal_id", table_name="food_logs")
    op.drop_constraint("fk_food_logs_saved_meal", "food_logs", type_="foreignkey")
    op.drop_column("food_logs", "meal_name")
    op.drop_column("food_logs", "meal_id")
    op.drop_index("ix_saved_meals_user_id", table_name="saved_meals")
    op.drop_table("saved_meals")
