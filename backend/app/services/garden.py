from datetime import date, datetime, time, timedelta
from collections import Counter

from sqlalchemy import select, func
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.food_log import FoodLog
from app.models.garden import GardenDay


async def credit_garden_day(db: AsyncSession, user_id: str, day: date) -> None:
    insert = sqlite_insert if db.get_bind().dialect.name == "sqlite" else pg_insert
    await db.execute(insert(GardenDay).values(user_id=user_id, day=day)
                     .on_conflict_do_nothing(index_elements=["user_id", "day"]))


async def sync_garden(db: AsyncSession, user_id: str, today: date) -> dict:
    """Backfill saved food days, preserve earned credits, return user's snapshot.

    Food timestamps follow the diary's existing client-local calendar convention.
    The endpoint performs no food/water mutations and never credits future dates.
    """
    food_dates = (await db.execute(select(func.date(FoodLog.date)).where(
        FoodLog.user_id == user_id,
        FoodLog.meal_type != "drinks",
        FoodLog.date < datetime.combine(today + timedelta(days=1), time.min),
    ).distinct())).scalars().all()
    insert = sqlite_insert if db.get_bind().dialect.name == "sqlite" else pg_insert
    credits = [{"user_id": user_id, "day": date.fromisoformat(raw) if isinstance(raw, str) else raw}
               for raw in food_dates]
    for offset in range(0, len(credits), 500):
        await db.execute(insert(GardenDay).values(credits[offset:offset + 500])
                         .on_conflict_do_nothing(index_elements=["user_id", "day"]))
    await db.commit()
    days = set((await db.execute(select(GardenDay.day).where(
        GardenDay.user_id == user_id, GardenDay.day <= today,
    ))).scalars().all())
    monday = today - timedelta(days=today.weekday())
    weeks = Counter((d.isocalendar().year, d.isocalendar().week) for d in days)
    return {
        "today": today.isoformat(),
        "total_days": len(days),
        "logged_today": today in days,
        "week_days": [{"date": (monday + timedelta(days=i)).isoformat(),
                       "earned": monday + timedelta(days=i) in days} for i in range(7)],
        "pot_unlocked": any(count >= 4 for count in weeks.values()),
    }
