"""Garden credits are tested only in disposable in-memory databases."""
from datetime import date, datetime, timedelta
import pytest
import pytest_asyncio
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from app.core.database import Base
from app.models.user import User
from app.models.food_log import FoodLog, WaterLog
from app.models.garden import GardenDay
from app.services.garden import sync_garden, credit_garden_day

TODAY = date(2026, 10, 20)


@pytest_asyncio.fixture
async def db():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    async with async_sessionmaker(engine, expire_on_commit=False)() as session:
        session.add_all([User(id="owner", full_name="Owner"), User(id="other", full_name="Other")])
        await session.commit()
        yield session
    await engine.dispose()


def food(id, day=TODAY, user="owner", meal="lunch"):
    return FoodLog(id=id, user_id=user, date=datetime.combine(day, datetime.min.time()),
        meal_type=meal, food_name=id, calories=100, protein=10, carbs=10, fat=2,
        quantity=100, unit="g")


@pytest.mark.asyncio
async def test_one_step_per_food_day_and_idempotent_backfill(db):
    db.add_all([food("rice"), food("fish"), food("yesterday", TODAY - timedelta(days=1)),
                food("foreign", TODAY - timedelta(days=2), user="other")])
    await db.commit()
    first = await sync_garden(db, "owner", TODAY)
    second = await sync_garden(db, "owner", TODAY)
    assert first == second
    assert first["total_days"] == 2
    assert first["logged_today"] is True
    assert len((await db.execute(select(GardenDay))).scalars().all()) == 2


@pytest.mark.asyncio
async def test_future_drinks_and_water_do_not_earn_steps(db):
    db.add_all([food("future", TODAY + timedelta(days=1)), food("drink", meal="drinks"),
        WaterLog(user_id="owner", date=datetime(2026, 10, 20), amount=250)])
    await db.commit()
    snapshot = await sync_garden(db, "owner", TODAY)
    assert snapshot["total_days"] == 0
    assert snapshot["logged_today"] is False
    next_day = await sync_garden(db, "owner", TODAY + timedelta(days=1))
    assert next_day["total_days"] == 1


@pytest.mark.asyncio
async def test_deleting_food_and_skipping_days_preserves_earned_growth(db):
    db.add(food("meal"))
    await db.commit()
    assert (await sync_garden(db, "owner", TODAY))["total_days"] == 1
    await db.execute(delete(FoodLog))
    await db.commit()
    later = await sync_garden(db, "owner", TODAY + timedelta(days=10))
    assert later["total_days"] == 1
    assert later["logged_today"] is False
    assert not any(day["earned"] for day in later["week_days"])


@pytest.mark.asyncio
async def test_reward_uses_calendar_week_and_stays_unlocked(db):
    monday = TODAY - timedelta(days=TODAY.weekday()) - timedelta(days=7)
    db.add_all(food(str(i), monday + timedelta(days=i)) for i in [0, 1, 3, 6])
    await db.commit()
    snapshot = await sync_garden(db, "owner", TODAY)
    assert snapshot["total_days"] == 4
    assert snapshot["pot_unlocked"] is True
    assert not any(day["earned"] for day in snapshot["week_days"])


@pytest.mark.asyncio
async def test_direct_credit_is_unique_and_survives_without_sync(db):
    await credit_garden_day(db, "owner", TODAY)
    await credit_garden_day(db, "owner", TODAY)
    await db.commit()
    assert (await sync_garden(db, "owner", TODAY))["total_days"] == 1
    assert (await sync_garden(db, "other", TODAY))["total_days"] == 0


@pytest.mark.asyncio
async def test_authenticated_sync_endpoint_uses_caller_and_validates_date(db):
    import httpx
    from fastapi import FastAPI
    from app.api.v1.routes.tracker import router
    from app.core.database import get_db
    from app.core.security import get_current_user_id
    app = FastAPI()
    app.include_router(router)
    async def override_db():
        yield db
    app.dependency_overrides[get_db] = override_db
    app.dependency_overrides[get_current_user_id] = lambda: "owner"
    db.add_all([food("mine"), food("theirs", TODAY - timedelta(days=1), user="other")])
    await db.commit()
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
        response = await client.post("/tracker/garden/sync", params={"today_str": "2026-10-20"})
        assert response.status_code == 200
        assert response.json()["total_days"] == 1
        assert len(response.json()["week_days"]) == 7
        assert (await client.post("/tracker/garden/sync", params={"today_str": "invalid"})).status_code == 400
