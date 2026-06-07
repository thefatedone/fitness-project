from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
from datetime import datetime
from typing import List
from app.core.database import get_db
from app.core.security import get_current_user_id
from app.models.food_log import FoodLog, WeightLog, WaterLog
from app.schemas.food import FoodLogCreate, FoodLogResponse, WaterLogCreate, WaterLogResponse, WeightLogCreate, WeightLogResponse, WeightLogHistoryResponse

router = APIRouter(prefix="/tracker", tags=["tracker"])


def parse_query_date(date_str: str) -> datetime:
    """Parse date string with error handling."""
    try:
        return datetime.fromisoformat(date_str.replace("Z", "+00:00"))
    except ValueError:
        try:
            return datetime.strptime(date_str, "%Y-%m-%d")
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD or ISO format.")


@router.get("/daily", response_model=List[FoodLogResponse])
async def get_daily_food(
    date_str: str = Query(...),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """Get all food logs for a specific date"""
    query_date = parse_query_date(date_str)
    start_of_day = query_date.replace(hour=0, minute=0, second=0, microsecond=0)
    end_of_day = query_date.replace(hour=23, minute=59, second=59, microsecond=999999)

    result = await db.execute(
        select(FoodLog).where(
            and_(
                FoodLog.user_id == user_id,
                FoodLog.date >= start_of_day,
                FoodLog.date <= end_of_day
            )
        )
    )
    return result.scalars().all()


@router.post("/food", response_model=FoodLogResponse)
async def add_food_log(
    food_data: FoodLogCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """Add a new food log entry"""
    food_log = FoodLog(
        user_id=user_id,
        date=food_data.date,
        meal_type=food_data.meal_type,
        food_name=food_data.food_name,
        calories=food_data.calories,
        protein=food_data.protein,
        carbs=food_data.carbs,
        fat=food_data.fat,
        fiber=food_data.fiber,
        quantity=food_data.quantity,
        unit=food_data.unit,
        photo_url=food_data.photo_url,
        ai_generated=getattr(food_data, 'ai_generated', False)
    )

    db.add(food_log)
    await db.commit()
    await db.refresh(food_log)
    return food_log


@router.delete("/food/{food_id}")
async def delete_food_log(
    food_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """Delete a food log entry"""
    result = await db.execute(
        select(FoodLog).where(and_(FoodLog.id == food_id, FoodLog.user_id == user_id))
    )
    food_log = result.scalar_one_or_none()

    if not food_log:
        raise HTTPException(status_code=404, detail="Food log not found")

    await db.delete(food_log)
    await db.commit()
    return {"message": "Deleted"}


@router.get("/water", response_model=List[WaterLogResponse])
async def get_water_logs(
    date_str: str = Query(...),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """Get water logs for a specific date"""
    query_date = parse_query_date(date_str)
    start_of_day = query_date.replace(hour=0, minute=0, second=0, microsecond=0)
    end_of_day = query_date.replace(hour=23, minute=59, second=59, microsecond=999999)

    result = await db.execute(
        select(WaterLog).where(
            and_(
                WaterLog.user_id == user_id,
                WaterLog.date >= start_of_day,
                WaterLog.date <= end_of_day
            )
        )
    )
    return result.scalars().all()


@router.post("/water", response_model=WaterLogResponse)
async def add_water_log(
    water_data: WaterLogCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """Add a water log entry"""
    water_log = WaterLog(
        user_id=user_id,
        date=water_data.date,
        amount=water_data.amount
    )

    db.add(water_log)
    await db.commit()
    await db.refresh(water_log)
    return water_log


@router.get("/weight", response_model=List[WeightLogResponse])
async def get_weight_logs(
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """Get all weight logs for current user"""
    result = await db.execute(
        select(WeightLog).where(WeightLog.user_id == user_id).order_by(WeightLog.date.desc())
    )
    return result.scalars().all()


@router.post("/weight", response_model=WeightLogResponse)
async def add_weight_log(
    weight_data: WeightLogCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """Add a weight log entry"""
    weight_log = WeightLog(
        user_id=user_id,
        date=weight_data.date,
        weight=weight_data.weight,
        note=weight_data.note
    )

    db.add(weight_log)
    await db.commit()
    await db.refresh(weight_log)
    return weight_log


@router.get("/weight/history", response_model=List[WeightLogHistoryResponse])
async def get_weight_logs_history(
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """Get all weight logs for current user with date as yyyy-MM-dd string"""
    result = await db.execute(
        select(WeightLog).where(WeightLog.user_id == user_id).order_by(WeightLog.date.desc())
    )
    weight_logs = result.scalars().all()
    return [WeightLogHistoryResponse.from_weight_log(wl) for wl in weight_logs]


@router.get("/food/search")
async def search_food(
    q: str = Query(...),
    db: AsyncSession = Depends(get_db)
):
    """Search foods - returns mock data for now"""
    mock_foods = [
        {"id": 1, "name": "Apple", "calories_per_100g": 52, "protein_per_100g": 0.3, "carbs_per_100g": 14, "fat_per_100g": 0.2},
        {"id": 2, "name": "Banana", "calories_per_100g": 89, "protein_per_100g": 1.1, "carbs_per_100g": 23, "fat_per_100g": 0.3},
        {"id": 3, "name": "Chicken Breast", "calories_per_100g": 165, "protein_per_100g": 31, "carbs_per_100g": 0, "fat_per_100g": 3.6},
        {"id": 4, "name": "Rice", "calories_per_100g": 130, "protein_per_100g": 2.7, "carbs_per_100g": 28, "fat_per_100g": 0.3},
        {"id": 5, "name": "Eggs", "calories_per_100g": 155, "protein_per_100g": 13, "carbs_per_100g": 1.1, "fat_per_100g": 11},
    ]
    query_lower = q.lower()
    results = [f for f in mock_foods if query_lower in f["name"].lower()]
    return results
