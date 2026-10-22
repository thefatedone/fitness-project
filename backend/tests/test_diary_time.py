from datetime import datetime
from uuid import uuid4
import pytest
from fastapi import HTTPException
from starlette.requests import Request
from app.services.diary_time import captured_time, diary_date
from test_saved_meals import fixture
from test_idempotent_saves import FOOD, BEVERAGE
from app.api.v1.routes.food_recognition import router


def request(offset, instant='2026-10-21T22:30:00Z'):
    return Request({'type':'http', 'headers':[
        (b'x-diary-offset-minutes', str(offset).encode()),
        (b'x-diary-captured-at', instant.encode())]})


@pytest.mark.parametrize('offset,expected',[
    (240, datetime(2026,10,22,2,30)),
    (-420, datetime(2026,10,21,15,30)),
    (345, datetime(2026,10,22,4,15)),
    (840, datetime(2026,10,22,12,30)),
    (-720, datetime(2026,10,21,10,30))])
def test_capture_uses_device_region_including_fractional_offsets(offset,expected):
    assert captured_time(request(offset)) == expected


def test_invalid_offset_and_naive_capture_rejected():
    for req in [request(900), request('bad'), request(240,'2026-10-21T12:00:00')]:
        with pytest.raises(HTTPException) as error:
            captured_time(req)
        assert error.value.status_code == 400


def test_explicit_diary_day_preserved_and_aware_instants_converted():
    req=request(240)
    assert diary_date(datetime(2026,10,20),req)==datetime(2026,10,20)
    assert diary_date(datetime.fromisoformat('2026-10-21T22:30:00+00:00'),req)==datetime(2026,10,22,2,30)


async def test_aware_manual_entry_appears_on_local_day_and_retry_is_stable(fixture):
    client,_,_,_=fixture
    headers={'Idempotency-Key':str(uuid4()), 'X-Diary-Offset-Minutes':'240',
             'X-Diary-Captured-At':'2026-10-21T22:30:00Z'}
    body={**FOOD,'date':'2026-10-21T22:30:00Z'}
    first=await client.post('/tracker/food',json=body,headers=headers)
    assert first.status_code==200, first.text
    assert first.json()['date']=='2026-10-22T02:30:00'
    assert (await client.get('/tracker/daily',params={'date_str':'2026-10-21'})).json()==[]
    assert len((await client.get('/tracker/daily',params={'date_str':'2026-10-22'})).json())==1
    assert (await client.post('/tracker/food',json=body,headers=headers)).json()==first.json()
    assert (await client.post('/tracker/food',json=body,headers={**headers,'X-Diary-Offset-Minutes':'-420'})).status_code==409


async def test_beverage_pair_keeps_original_capture_day_after_midnight_retry(fixture):
    client,_,app,_=fixture
    app.include_router(router)
    headers={'Idempotency-Key':str(uuid4()), 'X-Diary-Offset-Minutes':'345',
             'X-Diary-Captured-At':'2026-10-21T18:14:00Z'}
    first=await client.post('/food/log-beverage-manual',json=BEVERAGE,headers=headers)
    assert first.status_code==200, first.text
    assert first.json()['logged_at']=='2026-10-21T23:59:00'
    assert (await client.post('/food/log-beverage-manual',json=BEVERAGE,headers=headers)).json()==first.json()
    foods=(await client.get('/tracker/daily',params={'date_str':'2026-10-21'})).json()
    water=(await client.get('/tracker/water',params={'date_str':'2026-10-21'})).json()
    assert len(foods)==len(water)==1
    assert foods[0]['date']==water[0]['date']=='2026-10-21T23:59:00'


@pytest.mark.parametrize('beverage',[False,True])
async def test_photo_uses_capture_time_instead_of_completion_time(fixture,monkeypatch,beverage):
    from test_idempotent_saves import stub_ai
    client,_,app,_=fixture
    app.include_router(router)
    ai={**BEVERAGE,'confidence':'high'} if beverage else {
        **FOOD,'confidence':'high','ingredients':['rice'],'description':'Rice'}
    calls=stub_ai(monkeypatch,ai)
    headers={'Idempotency-Key':str(uuid4()),'X-Diary-Offset-Minutes':'240',
             'X-Diary-Captured-At':'2026-10-21T19:59:00Z'}
    route='/food/recognize-beverage' if beverage else '/food/recognize-and-log'
    first=await client.post(route,files={'file':('photo.jpg',b'image','image/jpeg')},headers=headers)
    assert first.status_code==200,first.text
    assert first.json()['logged_at']=='2026-10-21T23:59:00'
    again=await client.post(route,files={'file':('photo.jpg',b'image','image/jpeg')},headers=headers)
    assert again.json()==first.json()
    assert len(calls)==1


async def test_garden_credits_local_today_rather_than_server_calendar(fixture,monkeypatch):
    from app.api.v1.routes import tracker
    from app.models.garden import GardenDay
    from sqlalchemy import select
    from test_saved_meals import meal
    client,sessions,_,_=fixture
    monkeypatch.setattr(tracker,'local_now',lambda _:datetime(2030,1,2,0,5))
    headers={'X-Diary-Offset-Minutes':'840'}
    response=await client.post('/tracker/food',json={**FOOD,'date':'2030-01-02T00:01:00'},headers=headers)
    assert response.status_code==200,response.text
    data={**meal(),'date':'2030-01-02T00:02:00'}
    assert (await client.post('/tracker/meals',json=data,headers=headers)).status_code==200
    async with sessions() as db:
        days=(await db.execute(select(GardenDay))).scalars().all()
        assert len(days)==1
        assert str(days[0].day)=='2030-01-02'
