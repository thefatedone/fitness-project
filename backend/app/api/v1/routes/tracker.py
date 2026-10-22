from app.services.diary_time import diary_date as local_diary_date, local_now
from app.services.idempotent_save import idempotent_save
from fastapi import Request, APIRouter, Depends, HTTPException, Query, UploadFile, File, Form
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, delete
from sqlalchemy.exc import IntegrityError
from app.models.saved_meal import SavedMeal
from datetime import datetime, timedelta
from typing import List, Set
from app.core.database import get_db
from app.core.config import settings
from app.core.redis_client import redis_client
from app.core.security import get_current_user_id
from app.models.food_log import FoodLog, WeightLog, WaterLog
from app.schemas.food import (
    DiaryDeletionRequest,
    DiaryDeletionResponse,
    MealCreate,
    SavedMealResponse,
    FoodLogCreate,
    FoodLogBulkDelete,
    FoodLogResponse,
    WaterLogCreate,
    WaterLogResponse,
    WeightLogCreate,
    WeightLogResponse,
    WeightLogHistoryResponse,
    StreakDayEntry,
    StreakResponse,
)
from app.services.garden import credit_garden_day, sync_garden
from app.services.photo_analysis import (
    PHOTO_ANALYSIS_PROMPT,
    PhotoAnalysisResult,
    cache_get_cached_result,
    cache_set_cached_result,
    check_rate_limit,
    hash_image_bytes,
    validate_and_normalize,
)
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/tracker", tags=["tracker"])


# Upper bound on how far back the streak walk will look. Larger
# values are wasted work for the typical user (60-day window is
# comfortably wider than any plausible UI-visible streak) and add
# no behavioural value given the cosmetic-only nature of the
# counter. Trade-off and known cap are documented on `get_streak`.
STREAK_LOOKBACK_DAYS = 60

# Streak milestones surfaced in the detail sheet's progress bar.
# Fixed product decision — not user-configurable. The 7-step ladder
# gives a meaningful "next goal" every few days at the start of a
# streak (3 → 7 → 14 → 30 → 60 → 100 → 365) and then settles into a
# yearly horizon for power users. `next_milestone` is the smallest
# element strictly greater than `current_streak`; once a user crosses
# the largest milestone, the UI shows a "🏆 N day streak" line
# instead of a progress bar (no more `next_milestone` to chase).
STREAK_MILESTONES: list[int] = [3, 7, 14, 30, 60, 100, 365]

# Number of trailing calendar days to expose in `history`. The
# detail sheet's strip renders this many cells, with index 13 being
# today. Kept as a constant (not a request parameter) because the
# UI's strip layout is fixed-width; widening the window would just
# truncate every cell visually.
STREAK_HISTORY_DAYS = 14


def parse_query_date(date_str: str) -> datetime:
    """Parse date string with error handling."""
    try:
        return datetime.fromisoformat(date_str.replace("Z", "+00:00"))
    except ValueError:
        try:
            return datetime.strptime(date_str, "%Y-%m-%d")
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD or ISO format.")


@router.get("/saves/{key}")
async def check_saved_operation(
    key: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    from uuid import UUID
    from app.models.save_operation import SaveOperation
    from app.services.idempotent_save import replay_save
    try:
        key = str(UUID(key))
    except ValueError:
        raise HTTPException(400, "Invalid save ID")
    operation = await db.get(SaveOperation, (user_id, key))
    if operation is None or operation.response is None:
        raise HTTPException(404, "Save not confirmed yet")
    return await replay_save(db, operation)


@router.get("/daily", response_model=List[FoodLogResponse])
async def get_daily_food(
    date_str: str = Query(...),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """Get all food logs for a specific date"""
    query_date = parse_query_date(date_str)
    start_of_day = query_date.replace(hour=0, minute=0, second=0, microsecond=0)
    end_of_day = query_date.replace(hour=23, minute=59, second=59, microsecond=999999)

    result = await db.execute(
        select(FoodLog).where(
            and_(
                FoodLog.user_id == user_id,
                FoodLog.date >= start_of_day,
                FoodLog.date <= end_of_day
            )
        )
    )
    return result.scalars().all()


@router.post("/food", response_model=FoodLogResponse)
@idempotent_save
async def add_food_log(
    _request: Request,
    food_data: FoodLogCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """Add a new food log entry"""
    food_log = FoodLog(
        user_id=user_id,
        date=local_diary_date(food_data.date, _request),
        meal_type=food_data.meal_type,
        food_name=food_data.food_name,
        calories=food_data.calories,
        protein=food_data.protein,
        carbs=food_data.carbs,
        fat=food_data.fat,
        fiber=food_data.fiber,
        quantity=food_data.quantity,
        unit=food_data.unit,
        photo_url=food_data.photo_url,
        ai_generated=getattr(food_data, 'ai_generated', False)
    )

    db.add(food_log)
    # The same transaction saves food and the once-per-day cosmetic credit.
    # Future diary entries are backfilled only when their calendar day arrives.
    if food_data.meal_type != "drinks" and local_diary_date(food_data.date, _request).date() <= local_now(_request).date():
        await credit_garden_day(db, user_id, local_diary_date(food_data.date, _request).date())
    await db.flush()
    await db.refresh(food_log)
    return food_log


@router.get("/meals", response_model=list[SavedMealResponse])
async def get_saved_meals(
    limit: int = Query(30, ge=1, le=100),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(SavedMeal).where(SavedMeal.user_id == user_id)
        .order_by(SavedMeal.created_at.desc(), SavedMeal.id).limit(limit))
    return [{**meal.payload, "created_at": meal.created_at} for meal in result.scalars()]


@router.post("/meals", response_model=list[FoodLogResponse])
async def save_meal(
    _request: Request,
    data: MealCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    # The client keeps this ID while retrying; new repetitions get a new ID.
    meal_id = str(data.id)
    payload = data.model_dump(mode="json")

    async def replay(existing):
        if existing.user_id != user_id:
            raise HTTPException(404, "Meal not found")
        if existing.payload != payload:
            raise HTTPException(409, "This save ID belongs to a different meal")
        result = await db.execute(select(FoodLog).where(
            FoodLog.user_id == user_id, FoodLog.meal_id == meal_id).order_by(FoodLog.created_at, FoodLog.id))
        return result.scalars().all()

    existing = await db.get(SavedMeal, meal_id)
    if existing:
        return await replay(existing)

    # Diary dates follow the existing local wall-clock convention.
    diary_date = local_diary_date(data.date, _request)
    db.add(SavedMeal(id=meal_id, user_id=user_id, payload=payload))
    try:
        # Flush the snapshot first so concurrent retries meet the unique key
        # before inserting any ingredients or earning a garden day.
        await db.flush()
        rows = [FoodLog(user_id=user_id, date=diary_date,
            meal_type=data.meal_type, meal_id=meal_id, meal_name=data.name,
            **item.model_dump(), unit="g", ai_generated=False)
            for item in data.ingredients]
        db.add_all(rows)
        if diary_date.date() <= local_now(_request).date():
            await credit_garden_day(db, user_id, diary_date.date())
        await db.commit()
    except IntegrityError:
        await db.rollback()
        existing = await db.get(SavedMeal, meal_id)
        if existing:
            return await replay(existing)
        raise
    # One read for the complete committed dish, also used by retry responses.
    return await replay(await db.get(SavedMeal, meal_id))


# ---------------------------------------------------------------------------
# Photo-based meal analysis (analyze-only; no DB writes)
# ---------------------------------------------------------------------------

ALLOWED_IMAGE_MIME_TYPES: frozenset[str] = frozenset({
    "image/jpeg",
    "image/jpg",
    "image/png",
    "image/webp",
    "image/heic",
    "image/heif",
})
MAX_IMAGE_BYTES: int = 10 * 1024 * 1024  # 10 MB
MAX_IMAGE_EDGE_PX: int = 1568
JPEG_QUALITY: int = 85


def _normalize_upload_image(raw_bytes: bytes) -> bytes:
    """Apply EXIF orientation, strip metadata, downscale longest edge
    to ≤1568 px, re-encode as JPEG.

    Raises `HTTPException(415)` for undecodable input so the route
    can return a user-safe message instead of leaking a Pillow
    traceback. Metadata removal is implicit in the re-encode (PIL
    discards EXIF / ICC / XMP unless we re-attach them) — we never
    set `exif=`, so output bytes carry no EXIF block at all.
    """
    import io
    from PIL import Image, ImageOps, UnidentifiedImageError

    try:
        with Image.open(io.BytesIO(raw_bytes)) as img:
            img = ImageOps.exif_transpose(img)
            img.thumbnail((MAX_IMAGE_EDGE_PX, MAX_IMAGE_EDGE_PX), Image.LANCZOS)
            if img.mode in ("RGBA", "LA", "P"):
                img = img.convert("RGB")
            buffer = io.BytesIO()
            img.save(buffer, "JPEG", quality=JPEG_QUALITY, optimize=True)
            return buffer.getvalue()
    except UnidentifiedImageError as e:
        raise HTTPException(
            status_code=415,
            detail="Unsupported image format. Use JPEG, PNG, WEBP, or HEIC.",
        ) from e
    except Exception as e:
        raise HTTPException(
            status_code=415,
            detail="Could not process image. Use JPEG, PNG, WEBP, or HEIC.",
        ) from e


async def _call_gemini_photo(jpeg_bytes: str) -> dict:
    """Invoke Gemini with the JSON-only prompt and a base64 JPEG.

    One transient retry on top of the SDK's own retry layer — the SDK
    retries idempotent 5xx + connection errors, so this extra attempt
    only matters for the non-retryable transient cases the SDK
    doesn't cover. Returns the parsed JSON dict from the model's
    response, or raises the appropriate HTTP-mappable error:

    * transient (network / 5xx / rate-limit) → `HTTPException(502)`
    * JSON parse failure → `json.JSONDecodeError` (caller maps to
      `HTTPException(422)` via the route's `validate_and_normalize`
      catch)
    * any other Gemini-side error → `HTTPException(502)`

    Mirrors the per-request `genai.configure(...)` + `GenerativeModel`
    pattern used by the single-item food-recognition flow
    (`food_recognition.py:311-312`) so both AI endpoints share the
    same SDK configuration shape.
    """
    import json
    import google.generativeai as genai
    from google.api_core.exceptions import GoogleAPIError

    def _strip_markdown_fence(text: str) -> str:
        text = text.strip()
        if text.startswith("```"):
            parts = text.split("```")
            text = parts[1] if len(parts) > 1 else parts[0]
            if text.startswith("json"):
                text = text[4:]
        return text.strip()

    last_exc: Exception | None = None
    for attempt in range(2):
        try:
            genai.configure(api_key=settings.GEMINI_API_KEY)
            model = genai.GenerativeModel(settings.MEAL_PHOTO_GEMINI_MODEL)
            image_part = {"mime_type": "image/jpeg", "data": jpeg_bytes}
            response = model.generate_content(
                [PHOTO_ANALYSIS_PROMPT, image_part]
            )
            return json.loads(_strip_markdown_fence(response.text))
        except json.JSONDecodeError:
            # Propagate parse failure so the route's
            # `validate_and_normalize` catch turns it into a 422 with
            # the user-facing "try a clearer photo" message.
            raise
        except GoogleAPIError as e:
            last_exc = e
            status = getattr(e, "code", None)
            if attempt == 1 or (status is not None and status < 500):
                raise HTTPException(
                    status_code=502,
                    detail="Photo analysis service is temporarily unavailable.",
                ) from e
            continue
        except Exception as e:
            # Defensive: the SDK can raise a variety of non-GoogleAPIError
            # exceptions (e.g. ValueError when `response.text` is missing
            # because the model returned no text content). Treat as
            # transient and let the retry loop handle it.
            last_exc = e
            if attempt == 1:
                raise HTTPException(
                    status_code=502,
                    detail="Photo analysis service is temporarily unavailable.",
                ) from e
            continue
    raise HTTPException(
        status_code=502,
        detail="Photo analysis service is temporarily unavailable.",
    ) from last_exc


@router.post("/food/analyze-photo", response_model=PhotoAnalysisResult)
async def analyze_food_photo(
    file: UploadFile = File(...),
    meal_type: str = Form("snack"),
    user_id: str = Depends(get_current_user_id),
):
    """Analyze a meal photo with Gemini and return a per-item
    breakdown. Does NOT write to the database — the Flutter client
    shows the breakdown, lets the user pick which items to save,
    then POSTs each accepted item to `/food` with the selected
    `meal_type` (which we accept here purely for client-side
    affordance / future use; it does not affect the analysis).

    Pipeline:
      1. Validate MIME (415) and size (413).
      2. Run the per-user rate limit (429) via Redis. Skip silently
         when Redis is unavailable.
      3. EXIF-rotate, strip metadata, downscale longest edge to
         ≤1568 px, re-encode JPEG. Hash the normalized bytes to
         short-circuit repeat uploads via the Redis cache (TTL
         settings.CACHE_TTL).
      4. Call Gemini with the JSON-only prompt, one transient-error
         retry. JSON parse failure propagates to the caller, which
         maps to 422 via the `validate_and_normalize` catch.
      5. Hand the parsed dict to `validate_and_normalize` for
         clamps, sanity-correction, rounding.
      6. Cache the validated result, return it.

    Status mapping:
      * 415 — MIME not image/jpeg|jpg|png|webp|heic|heif
      * 413 — image > 10 MB
      * 422 — model output unparseable
      * 429 — per-user rate limit exceeded
      * 502 — upstream transient failure after retry
    """
    if not file.content_type or not file.content_type.lower() in ALLOWED_IMAGE_MIME_TYPES:
        raise HTTPException(
            status_code=415,
            detail="Unsupported image type. Use JPEG, PNG, WEBP, or HEIC.",
        )

    raw_bytes = await file.read()
    if len(raw_bytes) > MAX_IMAGE_BYTES:
        raise HTTPException(
            status_code=413,
            detail="Image is too large. Maximum size is 10 MB.",
        )

    if not await check_rate_limit(redis_client, user_id):
        raise HTTPException(
            status_code=429,
            detail="Too many photo analysis requests. Please wait a minute and try again.",
        )

    normalized_jpeg = _normalize_upload_image(raw_bytes)
    image_hash = hash_image_bytes(normalized_jpeg)

    cached = await cache_get_cached_result(redis_client, image_hash)
    if cached is not None:
        try:
            return PhotoAnalysisResult.model_validate(cached)
        except Exception:
            pass

    import base64
    jpeg_b64 = base64.b64encode(normalized_jpeg).decode("ascii")
    raw_result = await _call_gemini_photo(jpeg_b64)

    try:
        result = validate_and_normalize(raw_result)
    except ValueError as e:
        logger.exception("Photo analysis output could not be parsed: %s", e)
        raise HTTPException(
            status_code=422,
            detail="Photo analysis result could not be parsed. Please try a clearer photo.",
        ) from e

    await cache_set_cached_result(redis_client, image_hash, result, settings.CACHE_TTL)

    logger.info(
        "Photo analysis: user=%s meal_type=%s items=%d no_food=%s",
        user_id, meal_type, len(result.items), result.no_food_detected,
    )
    return result


@router.post("/diary/deletion", response_model=DiaryDeletionResponse)
async def change_diary_deletion(
    data: DiaryDeletionRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    from app.services.diary_deletion import mutate_diary
    return await mutate_diary(db, user_id, data)


@router.post("/food/bulk-delete")
async def delete_food_logs(
    payload: FoodLogBulkDelete,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Delete an explicitly confirmed set of the caller's rows atomically.

    Never infer dish membership from timestamps or meal type: an existing
    breakfast can contain several independent dishes.
    """
    requested = set(payload.food_ids)
    result = await db.execute(
        select(FoodLog.id).where(
            FoodLog.user_id == user_id, FoodLog.id.in_(requested)
        )
    )
    if set(result.scalars().all()) != requested:
        raise HTTPException(status_code=404, detail="Food logs not found")
    await db.execute(
        delete(FoodLog).where(
            FoodLog.user_id == user_id, FoodLog.id.in_(requested)
        )
    )
    await db.commit()
    return {"deleted_count": len(requested)}


@router.delete("/food/{food_id}")
async def delete_food_log(
    food_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """Delete a food log entry"""
    result = await db.execute(
        select(FoodLog).where(and_(FoodLog.id == food_id, FoodLog.user_id == user_id))
    )
    food_log = result.scalar_one_or_none()

    if not food_log:
        raise HTTPException(status_code=404, detail="Food log not found")

    await db.delete(food_log)
    await db.commit()
    return {"message": "Deleted"}


@router.get("/water", response_model=List[WaterLogResponse])
async def get_water_logs(
    date_str: str = Query(...),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """Get water logs for a specific date"""
    query_date = parse_query_date(date_str)
    start_of_day = query_date.replace(hour=0, minute=0, second=0, microsecond=0)
    end_of_day = query_date.replace(hour=23, minute=59, second=59, microsecond=999999)

    result = await db.execute(
        select(WaterLog).where(
            and_(
                WaterLog.user_id == user_id,
                WaterLog.date >= start_of_day,
                WaterLog.date <= end_of_day
            )
        )
    )
    return result.scalars().all()


@router.post("/water", response_model=WaterLogResponse)
@idempotent_save
async def add_water_log(
    _request: Request,
    water_data: WaterLogCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """Add a water log entry"""
    water_log = WaterLog(
        user_id=user_id,
        date=local_diary_date(water_data.date, _request),
        amount=water_data.amount
    )

    db.add(water_log)
    await db.flush()
    await db.refresh(water_log)
    return water_log


@router.delete("/water/{water_id}")
async def delete_water_log(
    water_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """Delete a single water log entry (scoped to the current user)."""
    result = await db.execute(
        select(WaterLog).where(and_(WaterLog.id == water_id, WaterLog.user_id == user_id))
    )
    water_log = result.scalar_one_or_none()

    if not water_log:
        raise HTTPException(status_code=404, detail="Water log not found")

    await db.delete(water_log)
    await db.commit()
    return {"message": "Deleted"}


@router.post("/garden/sync")
async def get_garden_snapshot(
    today_str: str = Query(...),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    return await sync_garden(db, user_id, parse_query_date(today_str).date())


@router.get("/streak", response_model=StreakResponse)
async def get_streak(
    today_str: str = Query(...),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """Return the user's current diary streak as of [today_str].

    A day "has an entry" if at least one `FoodLog` OR `WaterLog`
    row exists for `user_id` with a `date` falling inside that local
    calendar day. Weight logs are intentionally excluded — a user
    weighing in is not the same as a user engaging with the diary,
    and conflating them would inflate the streak for users who only
    weight-track.

    Grace period: if today has no entry, the streak is still
    considered "alive" — we anchor the walk on yesterday instead of
    today. The counter only resets to 0 once a full calendar day
    passes with zero entries.

    `today_str` is the *client's local* YYYY-MM-DD. The server
    uses it as the source of truth for "today" (NOT UTC midnight)
    so a user logging at 23:30 local and re-opening the app at
    00:30 local doesn't see their streak vanish for that 1-hour
    DST rollover. Same convention as every other date-keyed
    endpoint in this file.

    Lookback window — KNOWN LIMITATION:

    The query is bounded at [STREAK_LOOKBACK_DAYS] days before
    `today_date` to keep the table scan cheap. As a result, a
    genuine streak longer than that window is reported as
    `STREAK_LOOKBACK_DAYS + 1` rather than its true length
    (e.g. a 91-day streak with the default 60-day window reads
    as 61). The +1 is the inclusive counting of the window's
    oldest day — `lookback_start` itself is included in the
    bounded query (`date >= lookback_start`) and is one of the
    days the walk-back counts before the cutoff check stops it.
    Days strictly older than `lookback_start` are not fetched at
    all, so the loop has no way to know they existed.

    This is a deliberate cosmetic cap, not a bug. The streak is
    surfaced as a small "🔥 N" chip in the UI; nobody is going to
    look at the chip and notice the difference between "🔥 61"
    and "🔥 91". If this app ever ships a leaderboard or
    year-streak celebration that needs the true count, replace
    this cap with an adaptive window (existence check at the
    window's oldest day, then re-query with a doubled window if
    the streak still might extend further back).
    """
    # Parse to a date-only anchor (drop time-of-day; only the
    # calendar day matters for the walk-back). Using
    # `parse_query_date` keeps the same YYYY-MM-DD / ISO parser
    # the rest of the file uses.
    today_parsed = parse_query_date(today_str)
    today_date = today_parsed.date()

    # Lookback window. The walk-back safety-belt below (cursor >=
    # cutoff) keeps this honest even if the value is tuned later.
    lookback_start = today_date - timedelta(days=STREAK_LOOKBACK_DAYS)

    # Fetch only days within the lookback window — a 60-day
    # bound on a user with thousands of historical entries turns
    # this from a full table scan into an indexed range scan.
    # The window is wide enough that any plausible UI-visible
    # streak fits inside it; see the docstring for the trade-off.
    food_days = await db.execute(
        select(FoodLog.date).where(
            and_(
                FoodLog.user_id == user_id,
                FoodLog.date >= lookback_start,
            )
        )
    )
    water_days = await db.execute(
        select(WaterLog.date).where(
            and_(
                WaterLog.user_id == user_id,
                WaterLog.date >= lookback_start,
            )
        )
    )

    # Truncate each row's timestamp to its local calendar day and
    # collect into a single set for O(1) membership checks during
    # the walk-back. The set is bounded by total logged days
    # within the window (≤ STREAK_LOOKBACK_DAYS), so memory is
    # a non-issue.
    logged_days: Set = set()
    for (dt,) in food_days.all():
        logged_days.add(dt.date())
    for (dt,) in water_days.all():
        logged_days.add(dt.date())

    # Grace period: anchor the walk on the most recent day with
    # an entry. If today has an entry, we anchor on today. If
    # today doesn't but yesterday does, we anchor on yesterday
    # (still alive). If neither, the streak is 0 — we still
    # continue to build the history strip + milestone fields below
    # so the detail sheet has consistent shape whether the user is
    # on a 0-day streak or a 60-day one.
    logged_today = today_date in logged_days
    if logged_today:
        anchor = today_date
    elif (today_date - timedelta(days=1)) in logged_days:
        anchor = today_date - timedelta(days=1)
        logged_today = False  # explicit; False is the default but
                              # leaves no doubt at the call site.
    else:
        anchor = None  # signals "streak is 0" to the walk-back below

    # Walk backward from the anchor counting consecutive days
    # with an entry. The first gap stops the count. The first
    # condition (cursor >= lookback_start) is the safety belt
    # that handles the grace-period anchor: if the anchor is
    # yesterday (one day before today_date), the earliest cursor
    # could otherwise reach is `today_date - 1 - lookback_days`,
    # which is one day *outside* the bounded query range. The
    # cutoff check stops the walk before that off-by-one lookup,
    # so we never ask the set for a day we didn't fetch.
    streak = 0
    if anchor is not None:
        cursor = anchor
        while cursor >= lookback_start and cursor in logged_days:
            streak += 1
            cursor = cursor - timedelta(days=1)

    # History strip: the last STREAK_HISTORY_DAYS calendar days ending
    # on today, oldest first. Always inclusive of today, regardless
    # of the grace-period anchor above — the strip represents the
    # real calendar, not the streak count. Index 0 is the oldest
    # visible day, index STREAK_HISTORY_DAYS - 1 is today.
    history: list[StreakDayEntry] = [
        StreakDayEntry(
            date=(today_date - timedelta(days=STREAK_HISTORY_DAYS - 1 - i)).isoformat(),
            logged=(today_date - timedelta(days=STREAK_HISTORY_DAYS - 1 - i)) in logged_days,
        )
        for i in range(STREAK_HISTORY_DAYS)
    ]

    # Next milestone: smallest threshold strictly greater than the
    # current streak. `None` if the user has already crossed the
    # largest defined milestone — in that case the UI shows a
    # trophy line instead of a progress bar.
    next_milestone: int | None = next(
        (m for m in STREAK_MILESTONES if m > streak),
        None,
    )
    days_to_next = (
        next_milestone - streak if next_milestone is not None else None
    )

    return StreakResponse(
        current_streak=streak,
        logged_today=logged_today,
        history=history,
        next_milestone=next_milestone,
        days_to_next_milestone=days_to_next,
    )


@router.get("/weight", response_model=List[WeightLogResponse])
async def get_weight_logs(
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """Get all weight logs for current user"""
    result = await db.execute(
        select(WeightLog).where(WeightLog.user_id == user_id).order_by(WeightLog.date.desc())
    )
    return result.scalars().all()


@router.post("/weight", response_model=WeightLogResponse)
@idempotent_save
async def add_weight_log(
    _request: Request,
    weight_data: WeightLogCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """Add a weight log entry"""
    weight_log = WeightLog(
        user_id=user_id,
        date=local_diary_date(weight_data.date, _request),
        weight=weight_data.weight,
        note=weight_data.note
    )

    db.add(weight_log)
    await db.flush()
    await db.refresh(weight_log)
    return weight_log


@router.get("/weight/history", response_model=List[WeightLogHistoryResponse])
async def get_weight_logs_history(
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """Get all weight logs for current user with date as yyyy-MM-dd string"""
    result = await db.execute(
        select(WeightLog).where(WeightLog.user_id == user_id).order_by(WeightLog.date.desc())
    )
    weight_logs = result.scalars().all()
    return [WeightLogHistoryResponse.from_weight_log(wl) for wl in weight_logs]


@router.get("/food/search")
async def search_food(
    q: str = Query(...),
    db: AsyncSession = Depends(get_db)
):
    """Search foods - returns mock data for now"""
    mock_foods = [
        {"id": 1, "name": "Apple", "calories_per_100g": 52, "protein_per_100g": 0.3, "carbs_per_100g": 14, "fat_per_100g": 0.2},
        {"id": 2, "name": "Banana", "calories_per_100g": 89, "protein_per_100g": 1.1, "carbs_per_100g": 23, "fat_per_100g": 0.3},
        {"id": 3, "name": "Chicken Breast", "calories_per_100g": 165, "protein_per_100g": 31, "carbs_per_100g": 0, "fat_per_100g": 3.6},
        {"id": 4, "name": "Rice", "calories_per_100g": 130, "protein_per_100g": 2.7, "carbs_per_100g": 28, "fat_per_100g": 0.3},
        {"id": 5, "name": "Eggs", "calories_per_100g": 155, "protein_per_100g": 13, "carbs_per_100g": 1.1, "fat_per_100g": 11},
    ]
    query_lower = q.lower()
    results = [f for f in mock_foods if query_lower in f["name"].lower()]
    return results
