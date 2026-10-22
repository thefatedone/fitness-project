"""HTTP meal workflow tests, with a new disposable in-memory DB per test."""
from copy import deepcopy
from uuid import uuid4

import httpx
import pytest
import pytest_asyncio
from fastapi import FastAPI
from sqlalchemy import select, event
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.api.v1.routes.tracker import router
from app.core.database import Base, get_db
from app.core.security import get_current_user_id
from app.models.food_log import FoodLog
from app.models.saved_meal import SavedMeal
from app.models.user import User


@pytest_asyncio.fixture
async def fixture():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    sessions = async_sessionmaker(engine, expire_on_commit=False)
    async with sessions() as db:
        db.add_all([User(id="owner", full_name="Owner"), User(id="other", full_name="Other")])
        await db.commit()
    app = FastAPI()
    app.include_router(router)

    async def override_db():
        async with sessions() as db:
            yield db

    app.dependency_overrides[get_db] = override_db
    app.dependency_overrides[get_current_user_id] = lambda: "owner"
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app, raise_app_exceptions=False), base_url="http://test") as client:
        yield client, sessions, app, engine
    await engine.dispose()


def meal():
    return {"id": str(uuid4()), "name": "Chicken and rice", "date": "2026-10-20T12:00:00",
            "meal_type": "lunch", "ingredients": [
                {"food_name": "Chicken", "quantity": 150, "calories": 240, "protein": 40, "carbs": 0, "fat": 8},
                {"food_name": "Rice", "quantity": 100, "calories": 130, "protein": 3, "carbs": 28, "fat": 1}]}


async def test_save_retry_and_repeat_are_distinct_meals(fixture):
    client, sessions, _, _ = fixture
    data = meal()
    first = await client.post('/tracker/meals', json=data)
    assert first.status_code == 200
    rows = first.json()
    assert len(rows) == 2
    assert {r['meal_id'] for r in rows} == {data['id']}
    assert {r['meal_name'] for r in rows} == {data['name']}
    assert sum(r['calories'] for r in rows) == 370
    retry = await client.post('/tracker/meals', json=data)
    assert {r['id'] for r in retry.json()} == {r['id'] for r in rows}
    repeat = deepcopy(data)
    repeat.update(id=str(uuid4()), date='2026-10-21T09:00:00', meal_type='breakfast')
    repeat['ingredients'][0].update(quantity=75, calories=120, protein=20, fat=4)
    assert (await client.post('/tracker/meals', json=repeat)).status_code == 200
    daily = (await client.get('/tracker/daily', params={'date_str': '2026-10-20'})).json()
    assert sum(r['calories'] for r in daily) == 370
    daily = (await client.get('/tracker/daily', params={'date_str': '2026-10-21'})).json()
    assert sum(r['calories'] for r in daily) == 250
    async with sessions() as db:
        assert len((await db.execute(select(FoodLog))).scalars().all()) == 4


async def test_library_survives_diary_deletion_and_respects_owner(fixture):
    client, _, app, _ = fixture
    data = meal()
    rows = (await client.post('/tracker/meals', json=data)).json()
    response = await client.post('/tracker/food/bulk-delete', json={'food_ids': [r['id'] for r in rows]})
    assert response.status_code == 200
    library = (await client.get('/tracker/meals')).json()
    assert library[0]['ingredients'] == data['ingredients']
    # A retry must not resurrect a deleted diary entry.
    assert (await client.post('/tracker/meals', json=data)).json() == []
    app.dependency_overrides[get_current_user_id] = lambda: 'other'
    assert (await client.get('/tracker/meals')).json() == []
    assert (await client.post('/tracker/meals', json=data)).status_code == 404


async def test_changed_payload_cannot_reuse_save_id(fixture):
    client, sessions, _, _ = fixture
    data = meal()
    await client.post('/tracker/meals', json=data)
    data['ingredients'][0]['quantity'] = 25
    assert (await client.post('/tracker/meals', json=data)).status_code == 409
    async with sessions() as db:
        assert len((await db.execute(select(FoodLog))).scalars().all()) == 2


@pytest.mark.parametrize('change', ['empty', 'negative', 'blank', 'zero', 'too_many'])
async def test_invalid_ingredient_rejects_whole_meal(fixture, change):
    client, sessions, _, _ = fixture
    data = meal()
    if change == 'empty': data['ingredients'] = []
    elif change == 'negative': data['ingredients'][1]['calories'] = -1
    elif change == 'blank': data['ingredients'][1]['food_name'] = '   '
    elif change == 'zero': data['ingredients'][1]['quantity'] = 0
    else: data['ingredients'] *= 51
    assert (await client.post('/tracker/meals', json=data)).status_code == 422
    async with sessions() as db:
        assert not (await db.execute(select(FoodLog))).scalars().all()
        assert not (await db.execute(select(SavedMeal))).scalars().all()


async def test_database_error_does_not_leave_half_a_dish(fixture):
    client, sessions, _, engine = fixture
    def fail_food_insert(conn, cursor, statement, parameters, context, executemany):
        if statement.startswith('INSERT INTO food_logs'):
            raise RuntimeError('Simulated interrupted save')
    event.listen(engine.sync_engine, 'before_cursor_execute', fail_food_insert)
    response = await client.post('/tracker/meals', json=meal())
    event.remove(engine.sync_engine, 'before_cursor_execute', fail_food_insert)
    assert response.status_code == 500
    async with sessions() as db:
        assert not (await db.execute(select(FoodLog))).scalars().all()
        assert not (await db.execute(select(SavedMeal))).scalars().all()
