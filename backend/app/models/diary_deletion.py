"""Owned, idempotent deletion receipts. Restore preserves original row IDs."""
from sqlalchemy import Column, String, ForeignKey, JSON, DateTime
from app.core.database import Base
from app.models.food_log import utc_now


class DiaryDeletion(Base):
    __tablename__ = "diary_deletions"
    id = Column(String, primary_key=True)
    user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    selection = Column(JSON, nullable=False)
    snapshot = Column(JSON, nullable=False)
    state = Column(String, nullable=False)
    created_at = Column(DateTime, nullable=False, default=utc_now)
