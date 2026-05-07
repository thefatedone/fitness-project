from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from app.core.database import get_db
from app.models.food_log import FoodLog, WaterLog, WeightLog
from app.models.user import User
from app.schemas.food import (
    FoodLogCreate, FoodLogUpdate,
    FoodLogResponse, DailySummary, WaterLogCreate
)
from app.api.v1.routes.users import get_current_user
from datetime import datetime, date
from typing import Optional
from pydantic import BaseModel
import uuid
import google.generativeai as genai
import json
import re


class ImageAnalyzeRequest(BaseModel):
    image: str  # base64 encoded image
import json
import re

router = APIRouter()


@router.get("/daily", response_model=DailySummary)
async def get_daily(
    target_date: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    if target_date:
        day = datetime.strptime(target_date, "%Y-%m-%d").date()
    else:
        day = date.today()

    start = datetime.combine(day, datetime.min.time())
    end = datetime.combine(day, datetime.max.time())

    # Get food logs
    result = await db.execute(
        select(FoodLog).where(
            FoodLog.user_id == current_user.id,
            FoodLog.date >= start,
            FoodLog.date <= end
        )
    )
    logs = result.scalars().all()

    # Get water logs
    water_result = await db.execute(
        select(func.sum(WaterLog.amount)).where(
            WaterLog.user_id == current_user.id,
            WaterLog.date >= start,
            WaterLog.date <= end
        )
    )
    water_ml = water_result.scalar() or 0

    # Group by meal type
    meals = {"breakfast": [], "lunch": [], "dinner": [], "snack": []}
    totals = {"calories": 0, "protein": 0, "carbs": 0, "fat": 0, "fiber": 0}

    for log in logs:
        meal = log.meal_type if log.meal_type in meals else "snack"
        meals[meal].append({
            "id": log.id,
            "food_name": log.food_name,
            "calories": log.calories,
            "protein": log.protein,
            "carbs": log.carbs,
            "fat": log.fat,
            "quantity": log.quantity,
            "unit": log.unit,
        })
        totals["calories"] += log.calories
        totals["protein"] += log.protein
        totals["carbs"] += log.carbs
        totals["fat"] += log.fat
        totals["fiber"] += log.fiber or 0

    return DailySummary(
        date=str(day),
        total_calories=round(totals["calories"], 1),
        total_protein=round(totals["protein"], 1),
        total_carbs=round(totals["carbs"], 1),
        total_fat=round(totals["fat"], 1),
        total_fiber=round(totals["fiber"], 1),
        water_ml=water_ml,
        calorie_target=current_user.daily_cal_target,
        protein_target=current_user.protein_target,
        carbs_target=current_user.carbs_target,
        fat_target=current_user.fat_target,
        meals=meals,
    )


@router.post("/food", response_model=FoodLogResponse)
async def add_food(
    data: FoodLogCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    log = FoodLog(
        id=str(uuid.uuid4()),
        user_id=current_user.id,
        date=data.date or datetime.utcnow(),
        meal_type=data.meal_type,
        food_name=data.food_name,
        calories=data.calories,
        protein=data.protein,
        carbs=data.carbs,
        fat=data.fat,
        fiber=data.fiber,
        quantity=data.quantity,
        unit=data.unit,
    )
    db.add(log)
    await db.commit()
    await db.refresh(log)
    return log


@router.put("/food/{log_id}", response_model=FoodLogResponse)
async def update_food(
    log_id: str,
    data: FoodLogUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(FoodLog).where(
            FoodLog.id == log_id,
            FoodLog.user_id == current_user.id
        )
    )
    log = result.scalar_one_or_none()
    if not log:
        raise HTTPException(status_code=404, detail="Food log not found")

    for field, value in data.model_dump(exclude_none=True).items():
        setattr(log, field, value)

    await db.commit()
    await db.refresh(log)
    return log


@router.delete("/food/{log_id}")
async def delete_food(
    log_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(FoodLog).where(
            FoodLog.id == log_id,
            FoodLog.user_id == current_user.id
        )
    )
    log = result.scalar_one_or_none()
    if not log:
        raise HTTPException(status_code=404, detail="Food log not found")

    await db.delete(log)
    await db.commit()
    return {"message": "Deleted successfully"}


@router.post("/water")
async def log_water(
    data: WaterLogCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    log = WaterLog(
        id=str(uuid.uuid4()),
        user_id=current_user.id,
        amount=data.amount,
        date=data.date or datetime.utcnow(),
    )
    db.add(log)
    await db.commit()
    return {"message": "Water logged", "amount_ml": data.amount}


@router.post("/weight")
async def log_weight(
    weight: float,
    note: str = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    log = WeightLog(
        id=str(uuid.uuid4()),
        user_id=current_user.id,
        weight=weight,
        date=datetime.utcnow(),
        note=note,
    )
    db.add(log)
    current_user.current_weight = weight
    await db.commit()
    return {"message": "Weight logged", "weight": weight}


@router.get("/weight/history")
async def get_weight_history(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(WeightLog)
        .where(WeightLog.user_id == current_user.id)
        .order_by(WeightLog.date.asc())
        .limit(30)
    )
    logs = result.scalars().all()
    return [
        {"date": log.date.strftime("%Y-%m-%d"), "weight": log.weight}
        for log in logs
    ]


@router.post("/analyze-image")
async def analyze_food_image(
    data: ImageAnalyzeRequest,
    current_user: User = Depends(get_current_user),
):
    from app.core.config import settings

    if not settings.GOOGLE_GEMINI_API_KEY:
        raise HTTPException(status_code=500, detail="Gemini API key not configured")

    try:
        genai.configure(api_key=settings.GOOGLE_GEMINI_API_KEY)
        model = genai.GenerativeModel("gemini-2.0-flash")

        # Clean base64 string (remove data URL prefix if present)
        image_data = data.image
        if "," in image_data:
            image_data = image_data.split(",")[1]

        import base64
        image_bytes = base64.b64decode(image_data)

        prompt = """You are a nutrition expert. Analyze this food and estimate its calories and macros per 100g.
Respond ONLY with valid JSON in this exact format, no other text:
{"name": "food name", "calories_per_100g": number, "protein_per_100g": number, "carbs_per_100g": number, "fat_per_100g": number}"""

        image_part = {"mime_type": "image/jpeg", "data": image_bytes}
        response = model.generate_content([prompt, image_part])

        # Parse JSON response
        response_text = response.text.strip()
        # Remove markdown code blocks if present
        response_text = re.sub(r"```json\s*", "", response_text)
        response_text = re.sub(r"```\s*", "", response_text)
        result = json.loads(response_text)

        return {
            "name": result.get("name", "Unknown Food"),
            "calories_per_100g": float(result.get("calories_per_100g", 0)),
            "protein_per_100g": float(result.get("protein_per_100g", 0)),
            "carbs_per_100g": float(result.get("carbs_per_100g", 0)),
            "fat_per_100g": float(result.get("fat_per_100g", 0)),
        }
    except json.JSONDecodeError as e:
        raise HTTPException(status_code=500, detail=f"Failed to parse AI response: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Image analysis failed: {str(e)}")