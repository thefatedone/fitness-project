from datetime import date, datetime
from typing import Literal


def calculate_age(date_of_birth: datetime) -> int:
    today = date.today()
    return today.year - date_of_birth.year - (
        (today.month, today.day) < (date_of_birth.month, date_of_birth.day)
    )


def calculate_bmr(weight_kg: float, height_cm: float,
                  age: int, sex: str) -> float:
    base = 10 * weight_kg + 6.25 * height_cm - 5 * age
    return base + 5 if sex == "male" else base - 161


def calculate_tdee(bmr: float, activity_level: str) -> float:
    multipliers = {
        "sedentary": 1.2,
        "light": 1.375,
        "moderate": 1.55,
        "active": 1.725,
        "very_active": 1.9,
    }
    return bmr * multipliers.get(activity_level, 1.2)


def calculate_targets(tdee: float, goal: str,
                      pace_kg_per_week: float = 0.5) -> dict:
    adjustments = {
        "lose_weight": -pace_kg_per_week * 1100,
        "maintain": 0,
        "gain_muscle": 300,
        "eat_healthier": 0,
    }
    daily_calories = max(1200, tdee + adjustments.get(goal, 0))
    return {
        "calories": round(daily_calories),
        "protein": round(daily_calories * 0.30 / 4),
        "carbs": round(daily_calories * 0.40 / 4),
        "fat": round(daily_calories * 0.30 / 9),
    }