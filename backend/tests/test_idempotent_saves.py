"""Exactly-once requests use isolated DB fixtures; AI calls are stubbed."""
import json
from types import SimpleNamespace
from uuid import uuid4
import pytest
from sqlalchemy import select, event
from app.models.food_log import FoodLog, WaterLog, WeightLog
from app.models.save_operation import SaveOperation
from app.core.security import get_current_user_id
from app.api.v1.routes import food_recognition
from test_saved_meals import fixture

FOOD = {'date':'2026-10-21T12:00:00','meal_type':'lunch','food_name':'Rice','quantity':100,'unit':'g',
        'calories':130,'protein':3,'carbs':28,'fat':1}
WATER = {'date':'2026-10-21T12:00:00','amount':250}
WEIGHT = {'date':'2026-10-21T12:00:00','weight':70,'note':'Morning'}
BEVERAGE = {'beverage_name':'Water','volume_ml':250,'calories':0,'protein':0,'carbs':0,'fat':0,'sugar_g':0}


def headers(): return {'Idempotency-Key':str(uuid4())}


@pytest.mark.parametrize('route,body,model',[
    ('/tracker/food',FOOD,FoodLog),('/tracker/water',WATER,WaterLog),('/tracker/weight',WEIGHT,WeightLog)])
async def test_retry_returns_identical_id_but_new_intent_can_repeat_same_values(fixture,route,body,model):
    client,sessions,_,_=fixture
    key=headers()
    first=await client.post(route,json=body,headers=key)
    assert first.status_code==200, first.text
    again=await client.post(route,json=body,headers=key)
    assert again.json()==first.json()
    assert (await client.get('/tracker/saves/'+key['Idempotency-Key'])).json()==first.json()
    second=await client.post(route,json=body,headers=headers())
    assert second.status_code==200
    assert second.json()['id']!=first.json()['id']
    async with sessions() as db:
        assert len((await db.execute(select(model))).scalars().all())==2


async def test_key_rejects_changed_body_and_changed_route(fixture):
    client,sessions,_,_=fixture
    key=headers()
    assert (await client.post('/tracker/food',json=FOOD,headers=key)).status_code==200
    assert (await client.post('/tracker/food',json={**FOOD,'quantity':200},headers=key)).status_code==409
    assert (await client.post('/tracker/water',json=WATER,headers=key)).status_code==409
    async with sessions() as db:
        assert len((await db.execute(select(FoodLog))).scalars().all())==1
        assert not (await db.execute(select(WaterLog))).scalars().all()


async def test_keys_and_status_are_scoped_to_the_owner(fixture):
    client,sessions,app,_=fixture
    key=headers()
    first=(await client.post('/tracker/food',json=FOOD,headers=key)).json()
    app.dependency_overrides[get_current_user_id]=lambda:'other'
    assert (await client.get('/tracker/saves/'+key['Idempotency-Key'])).status_code==404
    other=await client.post('/tracker/food',json=FOOD,headers=key)
    assert other.status_code==200
    assert other.json()['id']!=first['id']


async def test_retry_of_a_deleted_entry_does_not_resurrect_it(fixture):
    client,sessions,_,_=fixture
    key=headers()
    row=(await client.post('/tracker/food',json=FOOD,headers=key)).json()
    await client.delete('/tracker/food/'+row['id'])
    assert (await client.post('/tracker/food',json=FOOD,headers=key)).status_code==410
    assert (await client.get('/tracker/saves/'+key['Idempotency-Key'])).status_code==410
    async with sessions() as db:
        assert not (await db.execute(select(FoodLog))).scalars().all()


async def test_failed_transaction_rolls_back_rows_and_save_receipt(fixture):
    client,sessions,_,engine=fixture
    key=headers()
    def fail(conn,cursor,statement,params,context,executemany):
        if statement.startswith('INSERT INTO food_logs'):raise RuntimeError('Simulated failure')
    event.listen(engine.sync_engine,'before_cursor_execute',fail)
    try:
        assert (await client.post('/tracker/food',json=FOOD,headers=key)).status_code==500
    finally:event.remove(engine.sync_engine,'before_cursor_execute',fail)
    async with sessions() as db:
        assert not (await db.execute(select(FoodLog))).scalars().all()
        assert not (await db.execute(select(SaveOperation))).scalars().all()
    assert (await client.post('/tracker/food',json=FOOD,headers=key)).status_code==200


async def test_old_clients_without_a_key_and_invalid_headers(fixture):
    client,_,_,_=fixture
    assert (await client.post('/tracker/water',json=WATER,headers={'Idempotency-Key':'bad'})).status_code==400
    assert (await client.post('/tracker/water',json=WATER)).status_code==200


def stub_ai(monkeypatch,data):
    calls=[]
    def generate(_):
        calls.append(1)
        return SimpleNamespace(text=json.dumps(data))
    monkeypatch.setattr(food_recognition.genai,'configure',lambda **kwargs:None)
    monkeypatch.setattr(food_recognition.genai,'GenerativeModel',lambda _:SimpleNamespace(generate_content=generate))
    return calls


@pytest.mark.parametrize('beverage',[False,True])
async def test_photo_replay_reuses_ai_result_and_saved_rows(fixture,monkeypatch,beverage):
    client,sessions,app,_=fixture
    app.include_router(food_recognition.router)
    ai = {**BEVERAGE,'confidence':'high'} if beverage else {
        **FOOD,'confidence':'high','ingredients':['rice'],'description':'Rice'}
    calls=stub_ai(monkeypatch,ai)
    key=headers()
    route='/food/recognize-beverage' if beverage else '/food/recognize-and-log'
    first=await client.post(route,files={'file':('photo.jpg',b'fake-image','image/jpeg')},headers=key)
    assert first.status_code==200, first.text
    again=await client.post(route,files={'file':('other-name.jpg',b'fake-image','image/jpeg')},headers=key)
    assert again.json()==first.json()
    assert len(calls)==1
    changed=await client.post(route,files={'file':('photo.jpg',b'different-image','image/jpeg')},headers=key)
    assert changed.status_code==409
    async with sessions() as db:
        assert len((await db.execute(select(FoodLog))).scalars().all())==1
        assert len((await db.execute(select(WaterLog))).scalars().all())==int(beverage)


async def test_beverage_manual_pair_and_suggestion_only_photo_retries(fixture,monkeypatch):
    client,sessions,app,_=fixture
    app.include_router(food_recognition.router)
    key=headers()
    first=await client.post('/food/log-beverage-manual',json=BEVERAGE,headers=key)
    assert first.status_code==200,first.text
    assert (await client.post('/food/log-beverage-manual',json=BEVERAGE,headers=key)).json()==first.json()
    calls=stub_ai(monkeypatch,{**BEVERAGE,'confidence':'medium'})
    key=headers()
    for _ in range(2):
        response=await client.post('/food/recognize-beverage',files={'file':('a.jpg',b'image','image/jpeg')},headers=key)
        assert response.status_code==200
        assert response.json()['auto_logged'] is False
    assert len(calls)==1
    async with sessions() as db:
        assert len((await db.execute(select(FoodLog))).scalars().all())==1
        assert len((await db.execute(select(WaterLog))).scalars().all())==1
