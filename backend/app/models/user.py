from sqlalchemy import Column, String, Float, Integer, DateTime, Boolean, Text
from sqlalchemy.orm import relationship
from app.core.database import Base
import uuid
from datetime import datetime, timezone


def utc_now():
    """Return current UTC time as naive datetime for database compatibility."""
    return datetime.now(timezone.utc).replace(tzinfo=None)


class User(Base):
    __tablename__ = "users"

    id               = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    email            = Column(String, unique=True, nullable=True, index=True)
    phone            = Column(String, unique=True, nullable=True, index=True)
    password_hash    = Column(String, nullable=True)
    full_name           = Column(String, nullable=False)
    date_of_birth    = Column(DateTime, nullable=True)
    sex              = Column(String, nullable=True)
    profile_photo    = Column(String, nullable=True)
    height           = Column(Float, nullable=True)
    current_weight   = Column(Float, nullable=True)
    target_weight    = Column(Float, nullable=True)
    activity_level   = Column(String, nullable=True)
    primary_goal     = Column(String, nullable=True)
    dietary_preferences = Column(Text, nullable=True)
    food_allergies = Column(Text, nullable=True)
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
    created_at       = Column(DateTime, default=utc_now)
    updated_at       = Column(DateTime, default=utc_now, onupdate=utc_now)

    # ----- email verification (soft reminder, NOT an access gate) -----
    #
    # Email verification is a non-blocking soft reminder. A user who
    # never verifies their email still has full access to the app —
    # `is_email_verified` just drives the "please verify your email"
    # banner on the home screen so the user notices and can verify
    # on their own schedule. The original spec was explicit about
    # this: never block login on unverified status.
    #
    # The two "code" columns hold an *active* 6-digit code per user.
    # Unlike password reset, we don't need a separate history table
    # here — a new code simply overwrites the old one. The code is
    # hashed with bcrypt before being stored so a raw DB read never
    # reveals a still-valid code. After a successful verify, the
    # verify-email route wipes these two columns back to NULL.
    is_email_verified = Column(Boolean, default=False, nullable=False)
    email_verification_code_hash = Column(String, nullable=True)
    email_verification_expires_at = Column(DateTime, nullable=True)

    food_logs     = relationship("FoodLog", back_populates="user", cascade="all, delete")
    weight_logs   = relationship("WeightLog", back_populates="user", cascade="all, delete")
    chat_messages = relationship("ChatMessage", back_populates="user", cascade="all, delete")
    water_logs    = relationship("WaterLog", back_populates="user", cascade="all, delete")
