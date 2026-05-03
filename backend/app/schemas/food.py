from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class FoodLogCreate(BaseModel):
    date: Optional[datetime] = None
    meal_type: str  # breakfast/lunch/dinner/snack
    food_name: str
    calories: float
    protein: float
    carbs: float
    fat: float
    fiber: Optional[float] = None
    quantity: float
    unit: str  # g, ml, cup, piece


class FoodLogUpdate(BaseModel):
    meal_type: Optional[str] = None
    food_name: Optional[str] = None
    calories: Optional[float] = None
    protein: Optional[float] = None
    carbs: Optional[float] = None
    fat: Optional[float] = None
    quantity: Optional[float] = None
    unit: Optional[str] = None


class FoodLogResponse(BaseModel):
    id: str
    user_id: str
    date: datetime
    meal_type: str
    food_name: str
    calories: float
    protein: float
    carbs: float
    fat: float
    fiber: Optional[float]
    quantity: float
    unit: str
    ai_generated: bool
    created_at: datetime

    class Config:
        from_attributes = True


class DailySummary(BaseModel):
    date: str
    total_calories: float
    total_protein: float
    total_carbs: float
    total_fat: float
    total_fiber: float
    water_ml: int
    calorie_target: Optional[int]
    protein_target: Optional[float]
    carbs_target: Optional[float]
    fat_target: Optional[float]
    meals: dict  # grouped by meal_type


class WaterLogCreate(BaseModel):
    amount: int  # ml
    date: Optional[datetime] = None