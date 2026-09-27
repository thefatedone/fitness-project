from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


class FoodLogBase(BaseModel):
    date: datetime
    meal_type: str
    food_name: str
    calories: float
    protein: float
    carbs: float
    fat: float
    fiber: Optional[float] = None
    quantity: float
    unit: str
    photo_url: Optional[str] = None


class FoodLogCreate(FoodLogBase):
    pass


class FoodLogResponse(FoodLogBase):
    id: str
    user_id: str
    ai_generated: bool = False
    created_at: datetime

    class Config:
        from_attributes = True


class ReanalyzeDescriptionRequest(BaseModel):
    """Body schema for `POST /api/v1/food/{food_id}/reanalyze`.

    After an AI photo-recognition result is auto-logged, the user
    may edit the free-text description (e.g. "actually it's pasta
    with parmesan, not pasta with cream"). This endpoint re-asks
    Gemini to re-estimate the macros using the EDITED TEXT ONLY —
    no image is re-uploaded — and updates the original row in
    place.

    `min_length=1` keeps the model from being asked to "re-estimate
    this food" with literally no information, which would otherwise
    produce a confident but useless answer. The exact character
    ceiling is not enforced here because genuinely long ingredient
    lists (a complex salad, a hot-pot recipe) are legitimate
    inputs and we don't want to silently 422 them — if a misuse
    pattern shows up in telemetry we can tighten later.
    """
    description: str = Field(
        ...,
        min_length=1,
        description="The user's edited text describing the food.",
    )


class ManualBeverageLogRequest(BaseModel):
    """Body schema for `POST /api/v1/food/log-beverage-manual`.

    The user-confirmed counterpart to the auto-logged branch of
    `POST /api/v1/food/recognize-beverage`: when Gemini returns
    medium / low confidence on a beverage photo (e.g. "brown fizzy
    liquid in a glass" could be any of several cola brands with
    different calorie counts), the client presents the AI's
    pre-filled values to the user as a *suggestion*. After the
    user confirms — possibly editing the name, volume, or macros —
    the client POSTs the final values here.

    No Gemini round-trip is involved on this path: the user has
    vouched for the numbers, so we trust them and write them
    straight through with `ai_generated=False`.

    Validation rules:
      * `beverage_name` — non-empty (otherwise the resulting
        `FoodLog.food_name` row would be useless for the day's
        list rendering).
      * `volume_ml > 0` — the dual-write creates a `WaterLog`
        row with `amount=volume_ml`; zero or negative volumes
        would create a meaningless "I drank 0 ml" row.
      * All macro fields default to `0` and must be `>= 0`,
        so the same endpoint can carry a "zero-calorie" entry
        (e.g. the user typed "water" with all-zero nutrition —
        water is the canonical beverage-with-no-macros case).
    """
    beverage_name: str = Field(
        ...,
        min_length=1,
        description="Display name for the beverage (e.g. 'Coca-Cola').",
    )
    volume_ml: float = Field(
        ...,
        gt=0,
        description="Volume in millilitres (positive; feeds WaterLog.amount).",
    )
    calories: float = Field(default=0, ge=0)
    protein: float = Field(default=0, ge=0)
    carbs: float = Field(default=0, ge=0)
    fat: float = Field(default=0, ge=0)
    sugar_g: float = Field(default=0, ge=0)


class WaterLogBase(BaseModel):
    date: datetime
    amount: int


class WaterLogCreate(WaterLogBase):
    pass


class WaterLogResponse(WaterLogBase):
    id: str
    user_id: str
    created_at: datetime

    class Config:
        from_attributes = True


class WeightLogBase(BaseModel):
    date: datetime
    weight: float
    note: Optional[str] = None


class WeightLogCreate(WeightLogBase):
    pass


class WeightLogResponse(WeightLogBase):
    id: str
    user_id: str
    created_at: datetime

    class Config:
        from_attributes = True


class WeightLogHistoryResponse(BaseModel):
    id: str
    date: str  # yyyy-MM-dd format
    weight: float
    note: Optional[str] = None

    @classmethod
    def from_weight_log(cls, wl):
        return cls(
            id=wl.id,
            date=wl.date.strftime("%Y-%m-%d") if hasattr(wl.date, 'strftime') else str(wl.date)[:10],
            weight=wl.weight,
            note=wl.note,
        )


class StreakDayEntry(BaseModel):
    """One cell in the 14-day streak history strip rendered in the
    detail bottom sheet.

    `date` is a YYYY-MM-DD string in the client's local timezone
    (matching `today_str`'s contract). The schema stores it as
    `str` rather than `datetime` because the field is consumed
    by the Flutter UI for display + comparison against today's
    local date; round-tripping through Python's `datetime.date`
    would add timezone-sensitive parsing for no gain (the date
    has no time-of-day component).
    """
    date: str  # yyyy-MM-dd format
    logged: bool


class StreakResponse(BaseModel):
    """Response shape for `GET /api/v1/tracker/streak`.

    The streak is *computed* from existing `food_logs` / `water_logs`
    rows on every request rather than persisted. Self-correcting:
    the counter can never drift out of sync with the underlying
    log data. The trade-off is one cheap DISTINCT-style query per
    request, which is negligible against the API surface this
    endpoint is called from (cold start + after every successful
    food / water save).

    `current_streak` semantics:
      * `0` — neither today nor yesterday has any food or water
        entry. The streak is broken.
      * `>= 1` — counting today (or yesterday, under the grace
        period) as the anchor and walking back, that many consecutive
        calendar days each had at least one entry.

    `logged_today` — whether today itself (per the client's local
    date) has at least one entry. This is what the UI uses to flip
    the streak badge from "alive today" to "still alive, log to
    keep" — the counter is unchanged across that flip; only the
    surface treatment moves.

    `history` — the last 14 calendar days ending on today (always
    inclusive of today, regardless of the grace-period anchor logic
    that drives `current_streak`). Oldest day is index 0, today is
    index 13. The UI renders this as a horizontal strip of cells,
    with each `logged` cell filled and each unlogged cell outlined.
    Today's cell gets a distinct ring in the UI so the user can
    always locate it in the strip.

    `next_milestone` — the smallest milestone strictly greater than
    `current_streak` from a fixed product-defined set
    (see `STREAK_MILESTONES` in `routes/tracker.py`). `None` if
    `current_streak` has met or passed the largest milestone
    (currently 365). The UI uses this to render a "X / Y days"
    progress bar toward the next milestone.

    `days_to_next_milestone` — `next_milestone - current_streak`
    when there is one. `None` alongside `next_milestone = None`.
    The UI renders this directly as the "X more days" caption.
    """
    current_streak: int
    logged_today: bool
    history: list[StreakDayEntry]
    next_milestone: int | None
    days_to_next_milestone: int | None
