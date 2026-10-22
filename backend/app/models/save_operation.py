from sqlalchemy import Column, String, JSON, DateTime, ForeignKey
from app.core.database import Base
from app.models.food_log import utc_now


class SaveOperation(Base):
    __tablename__ = "save_operations"
    user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    key = Column(String, primary_key=True)
    route = Column(String, nullable=False)
    fingerprint = Column(String, nullable=False)
    response = Column(JSON, nullable=True)
    resources = Column(JSON, nullable=False, default=dict)
    created_at = Column(DateTime, nullable=False, default=utc_now)
