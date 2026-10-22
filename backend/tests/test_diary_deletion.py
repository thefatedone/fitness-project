"""Undo and uncertain-request recovery use exact IDs in disposable databases."""
from uuid import uuid4
import pytest
from sqlalchemy import select, event
from app.core.security import get_current_user_id
from app.models.diary_deletion import DiaryDeletion
from app.models.food_log import FoodLog
from test_saved_meals import fixture, meal


async def saved_selection(client):
    data = meal()
    foods = (await client.post('/tracker/meals', json=data)).json()
    water = (await client.post('/tracker/water', json={'date': data['date'], 'amount': 250})).json()
    request = {'id': str(uuid4()), 'food_ids': [v['id'] for v in foods], 'water_ids': [water['id']]}
    return request, foods, water


async def test_delete_retry_undo_retry_preserve_every_original_field(fixture):
    client, sessions, _, _ = fixture
    request, original_foods, original_water = await saved_selection(client)
    for _ in range(2):
        assert (await client.post('/tracker/diary/deletion', json=request)).json()['state'] == 'deleted'
    async with sessions() as db:
        assert not (await db.execute(select(FoodLog))).scalars().all()
    for _ in range(2):
        assert (await client.post('/tracker/diary/deletion', json={**request, 'restore': True})).json()['state'] == 'restored'
    actual = (await client.get('/tracker/daily', params={'date_str':'2026-10-20'})).json()
    assert sorted(actual, key=lambda v: v['id']) == sorted(original_foods, key=lambda v: v['id'])
    assert (await client.get('/tracker/water', params={'date_str':'2026-10-20'})).json() == [original_water]
    # A delayed retry of the original delete must never remove restored rows.
    assert (await client.post('/tracker/diary/deletion', json=request)).json()['state'] == 'restored'
    async with sessions() as db:
        assert len((await db.execute(select(FoodLog))).scalars().all()) == 2


async def test_undo_arriving_before_delete_cancels_delayed_request(fixture):
    client, sessions, _, _ = fixture
    request, _, _ = await saved_selection(client)
    assert (await client.post('/tracker/diary/deletion', json={**request, 'restore':True})).status_code == 200
    assert (await client.post('/tracker/diary/deletion', json=request)).json()['state'] == 'restored'
    async with sessions() as db:
        assert len((await db.execute(select(FoodLog))).scalars().all()) == 2


async def test_mixed_missing_selection_is_atomic_and_can_be_retried(fixture):
    client, sessions, _, _ = fixture
    request, _, _ = await saved_selection(client)
    invalid = {**request, 'water_ids':['missing']}
    assert (await client.post('/tracker/diary/deletion', json=invalid)).status_code == 404
    async with sessions() as db:
        assert len((await db.execute(select(FoodLog))).scalars().all()) == 2
        assert not (await db.execute(select(DiaryDeletion))).scalars().all()
    assert (await client.post('/tracker/diary/deletion', json=request)).status_code == 200


async def test_receipts_and_originals_are_isolated_by_user(fixture):
    client, sessions, app, _ = fixture
    request, _, _ = await saved_selection(client)
    assert (await client.post('/tracker/diary/deletion', json=request)).status_code == 200
    app.dependency_overrides[get_current_user_id] = lambda: 'other'
    assert (await client.post('/tracker/diary/deletion', json={**request, 'restore':True})).status_code == 404
    foreign_selection = {**request, 'id':str(uuid4())}
    assert (await client.post('/tracker/diary/deletion', json=foreign_selection)).status_code == 404
    app.dependency_overrides[get_current_user_id] = lambda: 'owner'
    assert (await client.post('/tracker/diary/deletion', json={**request, 'restore':True})).status_code == 200


async def test_receipt_cannot_be_reused_for_another_selection(fixture):
    client, _, _, _ = fixture
    request, _, _ = await saved_selection(client)
    await client.post('/tracker/diary/deletion', json=request)
    assert (await client.post('/tracker/diary/deletion', json={**request,'food_ids':['another']})).status_code == 409
    assert (await client.post('/tracker/diary/deletion', json={'id':str(uuid4())})).status_code == 422


async def test_failed_restore_rolls_back_receipt_and_all_insertions(fixture):
    client, sessions, _, engine = fixture
    request, _, _ = await saved_selection(client)
    await client.post('/tracker/diary/deletion', json=request)
    def fail_insert(conn, cursor, statement, parameters, context, executemany):
        if statement.startswith('INSERT INTO food_logs'):
            raise RuntimeError('Simulated storage failure')
    event.listen(engine.sync_engine, 'before_cursor_execute', fail_insert)
    try:
        response = await client.post('/tracker/diary/deletion', json={**request,'restore':True})
    finally:
        event.remove(engine.sync_engine, 'before_cursor_execute', fail_insert)
    assert response.status_code == 500
    async with sessions() as db:
        assert not (await db.execute(select(FoodLog))).scalars().all()
        assert (await db.get(DiaryDeletion,request['id'])).state == 'deleted'
    assert (await client.post('/tracker/diary/deletion', json={**request,'restore':True})).status_code == 200
