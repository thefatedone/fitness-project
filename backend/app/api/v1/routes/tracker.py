from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
from datetime import datetime, timedelta
from typing import List, Set
from app.core.database import get_db
from app.core.security import get_current_user_id
from app.models.food_log import FoodLog, WeightLog, WaterLog
from app.schemas.food import (
    FoodLogCreate,
    FoodLogResponse,
    WaterLogCreate,
    WaterLogResponse,
    WeightLogCreate,
    WeightLogResponse,
    WeightLogHistoryResponse,
    StreakResponse,
)

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


@router.delete("/water/{water_id}")
async def delete_water_log(
    water_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """Delete a single water log entry (scoped to the current user)."""
    result = await db.execute(
        select(WaterLog).where(and_(WaterLog.id == water_id, WaterLog.user_id == user_id))
    )
    water_log = result.scalar_one_or_none()

    if not water_log:
        raise HTTPException(status_code=404, detail="Water log not found")

    await db.delete(water_log)
    await db.commit()
    return {"message": "Deleted"}


@router.get("/streak", response_model=StreakResponse)
async def get_streak(
    today_str: str = Query(...),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """Return the user's current diary streak as of [today_str].

    A day "has an entry" if at least one `FoodLog` OR `WaterLog`
    row exists for `user_id` with a `date` falling inside that
    local calendar day. Weight logs are intentionally excluded —
    a user weighing in is not the same as a user engaging with
    the diary, and conflating them would inflate the streak for
    users who only weight-track.

    Grace period: if today has no entry, the streak is still
    considered "alive" — we anchor the walk on yesterday instead
    of today. The counter only resets to 0 once a full calendar
    day passes with zero entries.

    `today_str` is the *client's local* YYYY-MM-DD. The server
    uses it as the source of truth for "today" (NOT UTC midnight)
    so a user logging at 23:30 local and re-opening the app at
    00:30 local doesn't see their streak vanish for that 1-hour
    DST rollover. Same convention as every other date-keyed
    endpoint in this file.
    """
    # Parse to a date-only anchor (drop time-of-day; only the
    # calendar day matters for the walk-back). Using
    # `parse_query_date` keeps the same YYYY-MM-DD / ISO parser
    # the rest of the file uses.
    today_parsed = parse_query_date(today_str)
    today_date = today_parsed.date()

    # Fetch every calendar day that has at least one entry.
    # Two DISTINCT queries + set merge (cheaper than fetching the
    # full row bodies — we only need the day key, not the row).
    # The query uses range scans per (user_id, date) since the
    # existing schema indexes that column.
    food_days = await db.execute(
        select(FoodLog.date).where(FoodLog.user_id == user_id)
    )
    water_days = await db.execute(
        select(WaterLog.date).where(WaterLog.user_id == user_id)
    )

    # Truncate each row's timestamp to its local calendar day and
    # collect into a single set for O(1) membership checks during
    # the walk-back. The set is bounded by total logged days
    # (typically < 1000), so memory is a non-issue.
    logged_days: Set = set()
    for (dt,) in food_days.all():
        logged_days.add(dt.date())
    for (dt,) in water_days.all():
        logged_days.add(dt.date())

    # Grace period: anchor the walk on the most recent day with
    # an entry. If today has an entry, we anchor on today. If
    # today doesn't but yesterday does, we anchor on yesterday
    # (still alive). If neither, the streak is 0 and we can
    # return early.
    logged_today = today_date in logged_days
    if logged_today:
        anchor = today_date
    elif (today_date - timedelta(days=1)) in logged_days:
        anchor = today_date - timedelta(days=1)
        logged_today = False  # explicit; False is the default but
                              # leaves no doubt at the call site.
    else:
        return StreakResponse(current_streak=0, logged_today=False)

    # Walk backward from the anchor counting consecutive days
    # with an entry. The first gap stops the count.
    streak = 0
    cursor = anchor
    while cursor in logged_days:
        streak += 1
        cursor = cursor - timedelta(days=1)

    return StreakResponse(
        current_streak=streak,
        logged_today=logged_today,
    )


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
