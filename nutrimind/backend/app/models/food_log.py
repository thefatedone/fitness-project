from sqlalchemy import Column, String, Float, Integer, DateTime, Boolean, ForeignKey
from sqlalchemy.orm import relationship
from app.core.database import Base
import uuid
from datetime import datetime


class FoodLog(Base):
    __tablename__ = "food_logs"

    id           = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id      = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    date         = Column(DateTime, nullable=False, index=True)
    meal_type    = Column(String, nullable=False)
    food_name    = Column(String, nullable=False)
    calories     = Column(Float, nullable=False)
    protein      = Column(Float, nullable=False)
    carbs        = Column(Float, nullable=False)
    fat          = Column(Float, nullable=False)
    fiber        = Column(Float, nullable=True)
    quantity     = Column(Float, nullable=False)
    unit         = Column(String, nullable=False)
    photo_url    = Column(String, nullable=True)
    ai_generated = Column(Boolean, default=False)
    created_at   = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="food_logs")


class WeightLog(Base):
    __tablename__ = "weight_logs"

    id         = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id    = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    weight     = Column(Float, nullable=False)
    date       = Column(DateTime, nullable=False)
    note       = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="weight_logs")


class WaterLog(Base):
    __tablename__ = "water_logs"

    id         = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id    = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    amount     = Column(Integer, nullable=False)
    date       = Column(DateTime, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="water_logs")