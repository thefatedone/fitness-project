from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class UserBase(BaseModel):
    email: Optional[str] = None
    phone: Optional[str] = None
    name: str


class UserUpdate(BaseModel):
    email: Optional[str] = None
    phone: Optional[str] = None
    full_name: Optional[str] = None
    date_of_birth: Optional[str] = None
    sex: Optional[str] = None
    height: Optional[float] = None
    current_weight: Optional[float] = None
    target_weight: Optional[float] = None
    activity_level: Optional[str] = None
    primary_goal: Optional[str] = None
    dietary_preferences: Optional[str] = None
    food_allergies: Optional[str] = None
    weight_loss_pace: Optional[float] = None
    profile_photo: Optional[str] = None


class UserResponse(BaseModel):
    id: str
    email: Optional[str]
    full_name: str
    role: str
    phone: Optional[str] = None
    date_of_birth: Optional[datetime] = None
    sex: Optional[str] = None
    height: Optional[float] = None
    current_weight: Optional[float] = None
    target_weight: Optional[float] = None
    activity_level: Optional[str] = None
    primary_goal: Optional[str] = None
    dietary_preferences: Optional[str] = None
    food_allergies: Optional[str] = None
    weight_loss_pace: Optional[float] = None
    bmr: Optional[float] = None
    tdee: Optional[float] = None
    daily_cal_target: Optional[int] = None
    protein_target: Optional[float] = None
    carbs_target: Optional[float] = None
    fat_target: Optional[float] = None
    is_active: bool = True
    created_at: datetime
    profile_photo: Optional[str] = None

    class Config:
        from_attributes = True