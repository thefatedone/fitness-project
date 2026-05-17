from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class FoodLogBase(BaseModel):
    date: datetime
    meal_type: str
    food_name: str
    calories: float
    protein: float
    carbs: float
    fat: float
    fiber: Optional[float] = None
    quantity: float
    unit: str
    photo_url: Optional[str] = None


class FoodLogCreate(FoodLogBase):
    pass


class FoodLogResponse(FoodLogBase):
    id: str
    user_id: str
    ai_generated: bool = False
    created_at: datetime

    class Config:
        from_attributes = True


class WaterLogBase(BaseModel):
    date: datetime
    amount: int


class WaterLogCreate(WaterLogBase):
    pass


class WaterLogResponse(WaterLogBase):
    id: str
    user_id: str
    created_at: datetime

    class Config:
        from_attributes = True


class WeightLogBase(BaseModel):
    date: datetime
    weight: float
    note: Optional[str] = None


class WeightLogCreate(WeightLogBase):
    pass


class WeightLogResponse(WeightLogBase):
    id: str
    user_id: str
    created_at: datetime

    class Config:
        from_attributes = True