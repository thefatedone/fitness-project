"""The decorated handler flushes; this boundary commits rows + replay together."""
import hashlib
import json
from functools import wraps
from uuid import UUID
from fastapi import HTTPException
from fastapi.encoders import jsonable_encoder
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from starlette.datastructures import UploadFile
from app.models.save_operation import SaveOperation
from app.services.diary_time import captured_time
from app.models.food_log import FoodLog, WaterLog, WeightLog

MODELS = {model.__tablename__: model for model in (FoodLog, WaterLog, WeightLog)}


async def replay_save(db, operation):
    for table, ids in operation.resources.items():
        model = MODELS[table]
        present = set((await db.execute(select(model.id).where(
            model.user_id == operation.user_id, model.id.in_(ids)))).scalars())
        if present != set(ids):
            raise HTTPException(410, "The previously saved entry was deleted")
    return operation.response


def resource_ids(result, encoded):
    if isinstance(result, (FoodLog, WaterLog, WeightLog)):
        return {result.__tablename__: [result.id]}
    if isinstance(encoded, dict):
        return {table: [encoded[field]] for field, table in
            (("food_log_id", "food_logs"), ("water_log_id", "water_logs")) if encoded.get(field)}
    return {}


def idempotent_save(handler):
    @wraps(handler)
    async def wrapped(*args, **kwargs):
        db = kwargs["db"]
        request = kwargs["_request"]
        user_id = kwargs["user_id"]
        raw_key = request.headers.get("Idempotency-Key")
        operation = None
        try:
            if "X-Diary-Captured-At" in request.headers:
                captured_time(request)  # Validate before any external AI call.
            if raw_key is not None:
                try:
                    key = str(UUID(raw_key))
                except ValueError:
                    raise HTTPException(400, "Idempotency-Key must be a UUID")
                values = {}
                for name, value in kwargs.items():
                    if name in ("db", "_request", "user_id"):
                        continue
                    if isinstance(value, UploadFile):
                        digest = hashlib.sha256()
                        size = 0
                        while chunk := await value.read(1024 * 1024):
                            size += len(chunk)
                            if size > 10 * 1024 * 1024:
                                raise HTTPException(413, "Maximum image size is 10MB")
                            digest.update(chunk)
                        await value.seek(0)
                        values[name] = {"sha256": digest.hexdigest()}
                    else:
                        values[name] = value.model_dump(mode="json") if isinstance(value, BaseModel) else jsonable_encoder(value)
                for header in ("X-Diary-Offset-Minutes", "X-Diary-Captured-At"):
                    if "X-Diary-Captured-At" in request.headers and header in request.headers:
                        values[header] = request.headers[header]
                fingerprint = hashlib.sha256(json.dumps(values, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
                route = request.url.path
                operation = await db.get(SaveOperation, (user_id, key))
                if operation is None:
                    operation = SaveOperation(user_id=user_id, key=key, route=route,
                        fingerprint=fingerprint, resources={})
                    db.add(operation)
                    try:
                        await db.flush()
                    except IntegrityError:
                        await db.rollback()
                        operation = await db.get(SaveOperation, (user_id, key))
                        if operation is None:
                            raise
                if operation.route != route or operation.fingerprint != fingerprint:
                    raise HTTPException(409, "Save ID belongs to different data")
                if operation.response is not None:
                    return await replay_save(db, operation)
            result = await handler(*args, **kwargs)
            # Serialize before committing: failures cannot leave rows without a
            # replay response. Handlers must not commit independently.
            encoded = jsonable_encoder(result)
            if operation is not None:
                operation.response = encoded
                operation.resources = resource_ids(result, encoded)
            await db.commit()
            return encoded
        except Exception:
            await db.rollback()
            raise
    return wrapped
