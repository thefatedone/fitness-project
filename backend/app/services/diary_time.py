"""Diary timestamps are local wall-clock values; never reinterpret legacy rows."""
from datetime import datetime, timedelta, timezone
from fastapi import HTTPException, Request


def client_zone(request: Request):
    raw = request.headers.get("X-Diary-Offset-Minutes")
    if raw is None:
        return timezone.utc
    try:
        minutes = int(raw)
        if not -720 <= minutes <= 840:
            raise ValueError
        return timezone(timedelta(minutes=minutes))
    except (ValueError, OverflowError):
        raise HTTPException(400, "Invalid diary timezone offset")


def local_now(request: Request):
    return datetime.now(client_zone(request)).replace(tzinfo=None)


def captured_time(request: Request):
    zone = client_zone(request)
    raw = request.headers.get("X-Diary-Captured-At")
    if raw is None:
        return local_now(request)
    try:
        value = datetime.fromisoformat(raw.replace("Z", "+00:00"))
        if value.tzinfo is None:
            raise ValueError
        return value.astimezone(zone).replace(tzinfo=None)
    except (ValueError, OverflowError):
        raise HTTPException(400, "Invalid diary capture time")


def diary_date(value: datetime, request: Request):
    # Naive dates explicitly select a diary day. Aware dates represent instants.
    zone = client_zone(request)
    if value.tzinfo is not None and request.headers.get("X-Diary-Offset-Minutes") is not None:
        value = value.astimezone(zone)
    return value.replace(tzinfo=None)
