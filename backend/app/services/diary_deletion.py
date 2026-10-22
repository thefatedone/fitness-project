"""Serialize undo with deletion using a unique receipt and a row lock."""
from datetime import datetime
from fastapi import HTTPException
from sqlalchemy import select, delete
from sqlalchemy.exc import IntegrityError
from app.models.diary_deletion import DiaryDeletion
from app.models.food_log import FoodLog, WaterLog


def snapshot_row(row):
    return {column.name: (value.isoformat() if isinstance(value, datetime) else value)
            for column in row.__table__.columns
            if (value := getattr(row, column.name)) is not None}


async def mutate_diary(db, user_id, data):
    operation_id = str(data.id)
    selection = {"food_ids": sorted(set(data.food_ids)), "water_ids": sorted(set(data.water_ids))}
    receipt = (await db.execute(select(DiaryDeletion).where(
        DiaryDeletion.id == operation_id).with_for_update())).scalar_one_or_none()
    if receipt is None:
        receipt = DiaryDeletion(id=operation_id, user_id=user_id, selection=selection,
                                snapshot={}, state="new")
        db.add(receipt)
        try:
            await db.flush()
        except IntegrityError:
            await db.rollback()
            receipt = (await db.execute(select(DiaryDeletion).where(
                DiaryDeletion.id == operation_id).with_for_update())).scalar_one()
    if receipt.user_id != user_id:
        raise HTTPException(404, "Deletion not found")
    if receipt.selection != selection:
        raise HTTPException(409, "Deletion ID belongs to another selection")

    if data.restore:
        if receipt.state == "deleted":
            # Exact IDs, timestamps, meal grouping and provenance are preserved.
            # Locking the receipt makes repeated undo requests insert only once.
            for model, key in ((FoodLog, "foods"), (WaterLog, "water")):
                for saved in receipt.snapshot.get(key, []):
                    values = dict(saved)
                    for field in ("date", "created_at"):
                        if field in values:
                            values[field] = datetime.fromisoformat(values[field])
                    if await db.get(model, values["id"]) is None:
                        db.add(model(**values))
        # Undo can arrive BEFORE a delayed delete. This terminal state cancels
        # that request too, rather than letting it delete restored entries later.
        receipt.state = "restored"
    elif receipt.state == "new":
        snapshot = {}
        for model, key, ids in ((FoodLog, "foods", selection["food_ids"]),
                                (WaterLog, "water", selection["water_ids"])):
            rows = (await db.execute(select(model).where(
                model.user_id == user_id, model.id.in_(ids)).with_for_update())).scalars().all()
            if {row.id for row in rows} != set(ids):
                raise HTTPException(404, "Diary entries not found")
            snapshot[key] = [snapshot_row(row) for row in rows]
        receipt.snapshot = snapshot
        for model, ids in ((FoodLog, selection["food_ids"]), (WaterLog, selection["water_ids"])):
            if ids:
                await db.execute(delete(model).where(model.user_id == user_id, model.id.in_(ids)))
        receipt.state = "deleted"
    await db.commit()
    return {"id": operation_id, "state": receipt.state}
