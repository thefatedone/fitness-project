from pydantic import BaseModel, EmailStr
from typing import Optional
from datetime import datetime


class UserBase(BaseModel):
    email: Optional[str] = None
    phone: Optional[str] = None
    name: str


class UserUpdate(BaseModel):
    email: Optional[str] = None
    phone: Optional[str] = None
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
    name: str
    role: str
    phone: Optional[str] = None
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
    bmr: Optional[float] = None
    tdee: Optional[float] = None
    daily_cal_target: Optional[int] = None
    protein_target: Optional[float] = None
    carbs_target: Optional[float] = None
    fat_target: Optional[float] = None
    is_active: bool = True
    created_at: datetime

    class Config:
        from_attributes = True