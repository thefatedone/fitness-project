from typing import List, Optional
from pydantic import BaseModel, field_validator
from datetime import datetime


def _coerce_tags(v):
    """Accept list[str] OR a comma-separated string. Return a clean list[str] or None.

    - Trims each item, drops blanks
    - Deduplicates case-insensitively, preserving the first-seen casing
    - Returns None when the input is empty / None / not a recognised shape, so the
      column is cleared on save.
    """
    if v is None or v == "":
        return None
    if isinstance(v, str):
        items = [s.strip() for s in v.split(",") if s.strip()]
    elif isinstance(v, list):
        items = [str(s).strip() for s in v if str(s).strip()]
    else:
        return None
    seen: set[str] = set()
    deduped: list[str] = []
    for item in items:
        key = item.lower()
        if key not in seen:
            seen.add(key)
            deduped.append(item)
    return deduped or None


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
    dietary_preferences: Optional[List[str]] = None
    food_allergies: Optional[List[str]] = None
    weight_loss_pace: Optional[float] = None
    profile_photo: Optional[str] = None

    @field_validator("dietary_preferences", "food_allergies", mode="before")
    @classmethod
    def _coerce_tags_field(cls, v):
        return _coerce_tags(v)


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
    dietary_preferences: Optional[List[str]] = None
    food_allergies: Optional[List[str]] = None
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

    @field_validator("dietary_preferences", "food_allergies", mode="before")
    @classmethod
    def _coerce_tags_field(cls, v):
        return _coerce_tags(v)

    class Config:
        from_attributes = True
