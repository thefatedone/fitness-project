from sqlalchemy import Column, String, Float, Integer, DateTime, Boolean, Text
from sqlalchemy.orm import relationship
from app.core.database import Base
import uuid
from datetime import datetime


class User(Base):
    __tablename__ = "users"

    id               = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    email            = Column(String, unique=True, nullable=True, index=True)
    phone            = Column(String, unique=True, nullable=True, index=True)
    password_hash    = Column(String, nullable=True)
    name             = Column(String, nullable=False)
    date_of_birth    = Column(DateTime, nullable=True)
    sex              = Column(String, nullable=True)
    profile_photo    = Column(String, nullable=True)
    height           = Column(Float, nullable=True)
    current_weight   = Column(Float, nullable=True)
    target_weight    = Column(Float, nullable=True)
    activity_level   = Column(String, nullable=True)
    primary_goal     = Column(String, nullable=True)
    dietary_prefs    = Column(Text, nullable=True)
    allergies        = Column(Text, nullable=True)
    weight_loss_pace = Column(Float, nullable=True)
    bmr              = Column(Float, nullable=True)
    tdee             = Column(Float, nullable=True)
    daily_cal_target = Column(Integer, nullable=True)
    protein_target   = Column(Float, nullable=True)
    carbs_target     = Column(Float, nullable=True)
    fat_target       = Column(Float, nullable=True)
    role             = Column(String, default="USER", nullable=False)
    is_active        = Column(Boolean, default=True)
    onboarding_step  = Column(Integer, default=1)
    created_at       = Column(DateTime, default=datetime.utcnow)
    updated_at       = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    food_logs     = relationship("FoodLog", back_populates="user", cascade="all, delete")
    weight_logs   = relationship("WeightLog", back_populates="user", cascade="all, delete")
    chat_messages = relationship("ChatMessage", back_populates="user", cascade="all, delete")
    water_logs    = relationship("WaterLog", back_populates="user", cascade="all, delete")