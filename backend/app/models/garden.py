from sqlalchemy import Column, Date, ForeignKey, String
from app.core.database import Base


class GardenDay(Base):
    """Permanent cosmetic credit: at most one growth step per calendar day."""
    __tablename__ = "garden_days"
    user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    day = Column(Date, primary_key=True)
