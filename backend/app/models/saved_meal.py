"""Immutable meal snapshots retained for reuse even after diary deletion."""
from sqlalchemy import Column, String, DateTime, ForeignKey, JSON
from app.core.database import Base
from app.models.food_log import utc_now


class SavedMeal(Base):
    __tablename__ = "saved_meals"

    id = Column(String, primary_key=True)
    user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    payload = Column(JSON, nullable=False)
    created_at = Column(DateTime, nullable=False, default=utc_now)
