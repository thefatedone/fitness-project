"""Batch deletion uses only disposable in-memory SQLite fixtures."""
from datetime import datetime

import httpx
import pytest
import pytest_asyncio
from fastapi import FastAPI
from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.api.v1.routes.tracker import router
from app.core.database import Base, get_db
from app.core.security import get_current_user_id
from app.models.food_log import FoodLog
from app.models.user import User


@pytest_asyncio.fixture
async def fixture():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        db.add_all([User(id="owner", full_name="Owner"), User(id="other", full_name="Other")])
        await db.flush()
        for food_id, user_id in [("rice", "owner"), ("fish", "owner"), ("keep", "owner"), ("foreign", "other")]:
            db.add(FoodLog(id=food_id, user_id=user_id, date=datetime(2026, 10, 20),
                           meal_type="lunch", food_name=food_id, calories=100,
                           protein=10, carbs=10, fat=2, quantity=100, unit="g"))
        await db.commit()
        app = FastAPI()
        app.include_router(router)

        async def override_db():
            yield db

        app.dependency_overrides[get_db] = override_db
        app.dependency_overrides[get_current_user_id] = lambda: "owner"
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as client:
            yield client, db
    await engine.dispose()


@pytest.mark.asyncio
async def test_deletes_selected_ingredients_and_preserves_same_meal_other_dish(fixture):
    client, db = fixture
    response = await client.post("/tracker/food/bulk-delete", json={"food_ids": ["rice", "fish", "rice"]})
    assert response.status_code == 200
    assert response.json() == {"deleted_count": 2}
    assert set((await db.execute(select(FoodLog.id))).scalars()) == {"keep", "foreign"}


@pytest.mark.asyncio
@pytest.mark.parametrize("bad_id", ["foreign", "missing"])
async def test_foreign_or_stale_selection_deletes_nothing(fixture, bad_id):
    client, db = fixture
    response = await client.post("/tracker/food/bulk-delete", json={"food_ids": ["rice", bad_id]})
    assert response.status_code == 404
    assert set((await db.execute(select(FoodLog.id))).scalars()) == {"rice", "fish", "keep", "foreign"}


@pytest.mark.asyncio
@pytest.mark.parametrize("ids", [[], ["x"] * 501])
async def test_empty_and_oversized_requests_are_rejected(fixture, ids):
    client, db = fixture
    response = await client.post("/tracker/food/bulk-delete", json={"food_ids": ids})
    assert response.status_code == 422
    assert len((await db.execute(select(FoodLog.id))).scalars().all()) == 4
