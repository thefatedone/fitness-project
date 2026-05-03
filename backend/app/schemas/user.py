from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class UserProfileUpdate(BaseModel):
    name: Optional[str] = None
    date_of_birth: Optional[datetime] = None
    sex: Optional[str] = None
    height: Optional[float] = None
    current_weight: Optional[float] = None
    target_weight: Optional[float] = None
    activity_level: Optional[str] = None
    primary_goal: Optional[str] = None
    dietary_prefs: Optional[str] = None
    allergies: Optional[str] = None
    weight_loss_pace: Optional[float] = None


class UserResponse(BaseModel):
    id: str
    email: Optional[str]
    phone: Optional[str]
    name: str
    role: str
    is_active: bool
    onboarding_step: int
    height: Optional[float]
    current_weight: Optional[float]
    target_weight: Optional[float]
    activity_level: Optional[str]
    primary_goal: Optional[str]
    daily_cal_target: Optional[int]
    protein_target: Optional[float]
    carbs_target: Optional[float]
    fat_target: Optional[float]
    created_at: datetime

    class Config:
        from_attributes = True