"""Photo-based meal analysis: response models + pure validation/sanity-correction.

The Anthropic tool-use call returns a raw dict that mirrors our JSON schema.
We re-validate it here with Pydantic, then apply server-side clamps and
sanity-correction rules so the values that hit the Flutter client (and
later the `FoodLog` write) are internally consistent regardless of how
loose the model was.

Public surface used by `app/api/v1/routes/tracker.py`:

  * `validate_and_normalize(raw)` — takes whatever Anthropic emitted,
    returns a `PhotoAnalysisResult`. Never raises for content issues;
    only raises `ValueError` when the response is unparseable JSON-shape
    wise (the route maps that to HTTP 422).
  * `PHOTO_ANALYSIS_TOOL` — the JSON schema passed to Anthropic as the
    `tools` parameter so the response is structured out of the box.
  * `PHOTO_ANALYSIS_PROMPT` — the system/user prompt. Kept here next to
    the schema it constrains so a future schema edit forces a prompt
    re-read.
  * `check_rate_limit(redis_client, user_id)` and the cache helpers —
    thin wrappers over the redis client that mirror its
    connection-tolerant error handling (skip silently if Redis is down).
"""
from __future__ import annotations

import hashlib
import json
import logging
import uuid
from typing import Any, Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Pydantic response models
# ---------------------------------------------------------------------------

class AnalyzedPoint(BaseModel):
    """Normalized 0..1 visual centre of an item in the image.

    Origin is top-left (matching the `plate_box` convention so the
    Flutter UI can render both on the same coordinate system).
    """
    model_config = ConfigDict(from_attributes=True)

    x: float = Field(..., ge=0.0, le=1.0)
    y: float = Field(..., ge=0.0, le=1.0)


class PlateBox(BaseModel):
    """Normalized bounding box around the plate / eating surface.

    All four components are 0..1 fractions of the image width/height.
    May be omitted by the model (a casual snapshot with no clear
    plate), so the parent makes it Optional and the validator leaves it
    `None` when absent.
    """
    model_config = ConfigDict(from_attributes=True)

    x: float = Field(..., ge=0.0, le=1.0)
    y: float = Field(..., ge=0.0, le=1.0)
    w: float = Field(..., ge=0.0, le=1.0)
    h: float = Field(..., ge=0.0, le=1.0)


class AnalyzedPer100g(BaseModel):
    """Per-100g nutritional reference values for a single item."""
    model_config = ConfigDict(from_attributes=True)

    kcal: float = Field(..., ge=0)
    protein: float = Field(..., ge=0)
    carbs: float = Field(..., ge=0)
    fat: float = Field(..., ge=0)


class AnalyzedTotals(BaseModel):
    """Absolute nutritional totals for a single item.

    Always `kcal` rounded to int, macros to one decimal — the
    user-visible contract is "calories are a whole number,
    macros are decimals". Enforced at construction time via
    validators, so any downstream caller (the route, tests, the
    future Flutter round-trip) sees the same rounded shape.
    """
    model_config = ConfigDict(from_attributes=True)

    kcal: int = Field(..., ge=0)
    protein: float = Field(..., ge=0)
    carbs: float = Field(..., ge=0)
    fat: float = Field(..., ge=0)


class AnalyzedItem(BaseModel):
    """One detected food/drink item on the plate."""
    model_config = ConfigDict(from_attributes=True)

    id: str = Field(..., min_length=1)
    name: str = Field(..., min_length=1)
    grams: float = Field(..., ge=5.0, le=1500.0)
    point: AnalyzedPoint
    confidence: float = Field(..., ge=0.0, le=1.0)
    per_100g: AnalyzedPer100g
    totals: AnalyzedTotals


class PhotoAnalysisResult(BaseModel):
    """Top-level response of `POST /api/v1/tracker/food/analyze-photo`.

    `items` is always present, possibly empty (when `no_food_detected`
    is true). `plate_box` is optional because the model can omit it
    when there's no clear plate in the photo. `totals` is the meal-
    level sum — never None, even on the no-food path (it's zeros).
    """
    model_config = ConfigDict(from_attributes=True)

    no_food_detected: bool = False
    plate_box: Optional[PlateBox] = None
    items: list[AnalyzedItem] = Field(default_factory=list)
    totals: AnalyzedTotals


# ---------------------------------------------------------------------------
# Gemini prompt
# ---------------------------------------------------------------------------
#
# The prompt is the only structured-output contract now — Gemini is
# asked to return raw JSON (no tool-use mode). The route's
# `validate_and_normalize` validates the dict against the
# `PhotoAnalysisResult` Pydantic model and applies the same clamps /
# sanity-correction as before, so the wire shape to the Flutter client
# is identical to the previous Anthropic-backed flow.

PHOTO_ANALYSIS_PROMPT: str = """You analyze a photo of a meal and identify every distinct food or drink item on it.

CALIBRATION PRINCIPLE
- BE CONSERVATIVE. Slight under-estimation is better than over-estimation.
- A typical home-cooked meal for one person totals 400-800 kcal. Restaurant portions 600-1200 kcal.
- A single food item on a plate is rarely over 300 g. Whole-meal weights rarely exceed 800 g.
- Per-100g values for a SINGLE food rarely exceed 600 kcal/100g. Pure fats/oils (884) are the only common exception.

WHAT TO LIST
- List every distinct food/drink item that contributes meaningful nutrition (>= 20 kcal).
- DO NOT double-count: if oil is in the salad dressing, do not list olive oil as a separate item.
- For creamy dishes (carbonara, alfredo, etc.): the sauce is PART of the pasta, not a separate item. List one pasta item, not "pasta + cream sauce".
- DO NOT list the same item twice (no "pasta" + "spaghetti" + "noodles").
- Skip pure garnishes that contribute negligible calories (a single parsley leaf, a sesame seed on top, etc.).

PORTION ESTIMATION (GRAMS, BE CONSERVATIVE)
- Standard adult portions (cooked weights):
  * Pasta/rice: 80-150 g
  * Meat/chicken/fish: 100-180 g
  * Vegetables (side): 50-150 g
  * Bread slice: ~30 g
- Sauces/dressings: a drizzle of oil is 5-10 g. A creamy sauce coating adds 30-50 g to the underlying food — do not list as a separate portion.
- Visible cues: standard dinner plate ~26 cm diameter; fork ~19 cm; teaspoon ~14 cm; tablespoon ~16 cm; mug ~350 ml; glass ~250 ml; bowl 250-450 ml.

NUTRITION (per 100 g, widely-known reference values)
- raw chicken breast 165 kcal / 31p / 0c / 3.6f
- cooked white rice 130 kcal / 2.7p / 28c / 0.3f
- whole milk 61 kcal / 3.2p / 4.8c / 3.3f
- olive oil 884 kcal / 0p / 0c / 100f
- pasta (cooked, plain) ~130 kcal / 5p / 25c / 1f
- bacon (cooked) ~540 kcal / 37p / 1c / 42f
- parmesan cheese ~430 kcal / 38p / 4c / 29f
- egg (whole) ~155 kcal / 13p / 1c / 11f
- carbonara sauce (per 100g of coated pasta) ~200-250 kcal/100g

EXAMPLES (calibrate against these)
- A bowl of carbonara for one person: 100 g pasta + 25 g bacon + 20 g parmesan + 1 egg (~50 g). Total: ~600 kcal.
- A chicken salad: 150 g chicken + 80 g lettuce + 30 g dressing. Total: ~450 kcal.
- A burrito: 250 g (tortilla + fillings). Total: ~650 kcal.
- A slice of pizza: 120 g. Total: ~300 kcal.
- A cheeseburger: 230 g (bun + patty + cheese + toppings). Total: ~550 kcal.

GEOMETRY (visual localisation in the image)
- For each item, give `point` — the normalized 0..1 visual centre of the item in the image. x is the horizontal centre (0 = left edge, 1 = right edge), y is the vertical centre (0 = top edge, 1 = bottom edge).
- If you can identify the plate or main eating surface, give `plate_box` as the normalized bounding box (x, y top-left; w, h width/height; all 0..1). Omit `plate_box` when there is no clear plate.

CONFIDENCE
- For each item, give `confidence` 0..1 reflecting how sure you are about both identification AND portion size. A clearly-visible, easy-to-identify food in a standard portion gets 0.85-0.95; ambiguous foods get 0.4-0.6.

NO FOOD
- If the image contains no food or drink (empty plate, landscape, person, object, pet, etc.), return `no_food_detected: true` and an empty `items` array.

OUTPUT
- Return ONLY valid JSON. No prose, no markdown, no code fences, no explanation outside the JSON.
- Top-level object: `no_food_detected` (bool), optional `plate_box` (object with `x, y, w, h` all 0..1), `items` (array).
- Each item: `id` (short string, unique across the array, e.g. "item-1"), `name` (string), `grams` (number 5..500), `point` (`{x, y}` both 0..1), `confidence` (number 0..1), `per_100g` (`{kcal, protein, carbs, fat}` all non-negative numbers).
"""


# ---------------------------------------------------------------------------
# Pure validation / sanity-correction
# ---------------------------------------------------------------------------

MIN_GRAMS: float = 5.0
# Realistic cap for a single food item on a plate. The Pydantic
# schema's `le=1500.0` is the absolute defensive upper bound (kept
# for a future "family-size share" item); 500 g is the realistic
# ceiling for any normal single-portion food. Above this we cap
# grams, which brings the per-item kcal back to reality.
MAX_GRAMS: float = 500.0
# Tolerance for the kcal vs Atwater sanity check: when |stated - derived|
# / stated > this fraction, we trust the macros and recompute kcal.
# Tightened from 0.20 to 0.10 — macros are usually more accurate than
# the model's reported kcal, so a smaller disagreement almost always
# means the kcal is wrong.
KCAL_SANITY_TOLERANCE: float = 0.10
# If `stated_kcal` is exactly 0 we skip the ratio comparison (no
# reference) and adopt the derived value only when there are non-zero
# macros — otherwise both are zero and the item legitimately has zero
# calories (e.g. plain water).
# Per-item kcal safety net. A single food item totalling more than
# this is almost always a portion-estimation error by the model
# (carbonara portions, rib-eye steaks, large cheeseburgers can all
# hit 800-1000 kcal, but anything over 1200 is suspicious for a
# single item on a plate). When triggered, we scale grams down so
# the item's totals land at the cap.
MAX_ITEM_TOTAL_KCAL: float = 1200.0


def _round_kcal(value: float) -> int:
    return int(round(value))


def _round_macro(value: float) -> float:
    return round(value, 1)


def _clamp(value: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, value))


def _atwater_kcal(per_100g: AnalyzedPer100g) -> float:
    """Atwater-style kcal estimate: 4·protein + 4·carbs + 9·fat."""
    return 4.0 * per_100g.protein + 4.0 * per_100g.carbs + 9.0 * per_100g.fat


def _build_item(raw: dict[str, Any]) -> Optional[AnalyzedItem]:
    """Build one `AnalyzedItem` from the model's raw dict, applying
    clamps, sanity-correction, and rounding. Returns `None` when the
    raw item is unsalvageable (non-positive gram weight after
    clamping, or non-positive per-100g values across the board).

    The "drop items with non-positive values" rule (per the spec) is
    applied here: any item whose per_100g kcal is non-positive AND
    has zero grams-level nutrition contribution is dropped.
    Practically that means items where every per_100g macro is 0 —
    those contribute nothing to the meal totals and would just be
    noise in the UI.
    """
    if not isinstance(raw, dict):
        return None

    raw_id = raw.get("id")
    raw_name = raw.get("name")
    raw_grams = raw.get("grams")
    raw_point = raw.get("point")
    raw_confidence = raw.get("confidence")
    raw_per_100g = raw.get("per_100g")

    if raw_id is None or raw_name is None or raw_grams is None or raw_point is None \
            or raw_confidence is None or raw_per_100g is None:
        return None
    if not isinstance(raw_id, str) or not raw_id:
        return None
    if not isinstance(raw_name, str) or not raw_name:
        return None
    if not isinstance(raw_grams, (int, float)) or raw_grams <= 0:
        return None
    if not isinstance(raw_point, dict):
        return None
    if not isinstance(raw_per_100g, dict):
        return None
    if not isinstance(raw_confidence, (int, float)):
        return None

    grams = _clamp(float(raw_grams), MIN_GRAMS, MAX_GRAMS)

    p = raw_per_100g
    if not all(isinstance(p.get(k), (int, float)) for k in ("kcal", "protein", "carbs", "fat")):
        return None
    kcal_p100 = max(0.0, float(p["kcal"]))
    protein_p100 = max(0.0, float(p["protein"]))
    carbs_p100 = max(0.0, float(p["carbs"]))
    fat_p100 = max(0.0, float(p["fat"]))

    if kcal_p100 == 0 and protein_p100 == 0 and carbs_p100 == 0 and fat_p100 == 0:
        return None

    derived = _atwater_kcal(
        AnalyzedPer100g(kcal=kcal_p100, protein=protein_p100, carbs=carbs_p100, fat=fat_p100)
    )
    if kcal_p100 > 0 and abs(kcal_p100 - derived) / kcal_p100 > KCAL_SANITY_TOLERANCE:
        kcal_p100 = derived

    per_100g = AnalyzedPer100g(
        kcal=_round_kcal(kcal_p100),
        protein=_round_macro(protein_p100),
        carbs=_round_macro(carbs_p100),
        fat=_round_macro(fat_p100),
    )

    factor = grams / 100.0
    totals = AnalyzedTotals(
        kcal=_round_kcal(per_100g.kcal * factor),
        protein=_round_macro(per_100g.protein * factor),
        carbs=_round_macro(per_100g.carbs * factor),
        fat=_round_macro(per_100g.fat * factor),
    )

    # Per-item kcal safety net. If the model over-estimated the
    # portion (e.g. reported 800 g of carbonara at 540 kcal/100g,
    # which would total 4320 kcal — clearly wrong for a single
    # item), scale grams down so the item lands at the cap. The
    # per-100g reference is preserved, only the portion is corrected
    # — so a 100 g cap-reduced item at 540 kcal/100g still reads as
    # 540 kcal/100g bacon and 100 g of bacon, which the user can
    # then nudge in the UI if they want a different portion.
    if per_100g.kcal > 0:
        unrounded_total_kcal = per_100g.kcal * grams / 100.0
        if unrounded_total_kcal > MAX_ITEM_TOTAL_KCAL:
            capped_grams = (MAX_ITEM_TOTAL_KCAL / per_100g.kcal) * 100.0
            grams = max(MIN_GRAMS, min(MAX_GRAMS, capped_grams))
            factor = grams / 100.0
            totals = AnalyzedTotals(
                kcal=_round_kcal(per_100g.kcal * factor),
                protein=_round_macro(per_100g.protein * factor),
                carbs=_round_macro(per_100g.carbs * factor),
                fat=_round_macro(per_100g.fat * factor),
            )

    px = raw_point.get("x")
    py = raw_point.get("y")
    if not isinstance(px, (int, float)) or not isinstance(py, (int, float)):
        return None
    point = AnalyzedPoint(
        x=_clamp(float(px), 0.0, 1.0),
        y=_clamp(float(py), 0.0, 1.0),
    )

    confidence = _clamp(float(raw_confidence), 0.0, 1.0)

    return AnalyzedItem(
        id=raw_id,
        name=raw_name,
        grams=grams,
        point=point,
        confidence=confidence,
        per_100g=per_100g,
        totals=totals,
    )


def _build_plate_box(raw: Any) -> Optional[PlateBox]:
    if raw is None:
        return None
    if not isinstance(raw, dict):
        return None
    try:
        x = _clamp(float(raw["x"]), 0.0, 1.0)
        y = _clamp(float(raw["y"]), 0.0, 1.0)
        w = _clamp(float(raw["w"]), 0.0, 1.0)
        h = _clamp(float(raw["h"]), 0.0, 1.0)
    except (KeyError, TypeError, ValueError):
        return None
    return PlateBox(x=x, y=y, w=w, h=h)


def _sum_totals(items: list[AnalyzedItem]) -> AnalyzedTotals:
    kcal = sum(i.totals.kcal for i in items)
    protein = sum(i.totals.protein for i in items)
    carbs = sum(i.totals.carbs for i in items)
    fat = sum(i.totals.fat for i in items)
    return AnalyzedTotals(
        kcal=_round_kcal(kcal),
        protein=_round_macro(protein),
        carbs=_round_macro(carbs),
        fat=_round_macro(fat),
    )


def validate_and_normalize(raw: dict[str, Any]) -> PhotoAnalysisResult:
    """Validate the raw Anthropic tool-use input and return a clean
    `PhotoAnalysisResult`.

    Applies:
      * clamping coordinates to [0, 1] and grams to [5, 1500]
      * dropping items with non-positive values
      * recomputing `totals = per_100g * grams / 100` server-side
      * rounding kcal to int, macros to one decimal
      * sanity-correction when the stated kcal disagrees with the
        Atwater-style macros by more than 20 %

    Empty/garbage item dicts are skipped silently — the model
    occasionally returns an item it started writing then abandoned.
    Raises `ValueError` when the top-level shape is wrong (no
    `items` key, etc.) so the route can map it to HTTP 422.
    """
    if not isinstance(raw, dict):
        raise ValueError("Model output is not an object")

    no_food_detected = bool(raw.get("no_food_detected", False))
    raw_items = raw.get("items", [])
    if not isinstance(raw_items, list):
        raise ValueError("`items` is not an array")

    plate_box = _build_plate_box(raw.get("plate_box"))

    items: list[AnalyzedItem] = []
    seen_ids: set[str] = set()
    for raw_item in raw_items:
        built = _build_item(raw_item)
        if built is None:
            continue
        if built.id in seen_ids:
            built = built.model_copy(update={"id": new_item_id()})
        seen_ids.add(built.id)
        items.append(built)

    if no_food_detected and items:
        no_food_detected = False
    if no_food_detected:
        items = []
        plate_box = None

    return PhotoAnalysisResult(
        no_food_detected=no_food_detected,
        plate_box=plate_box,
        items=items,
        totals=_sum_totals(items),
    )


def hash_image_bytes(data: bytes) -> str:
    """Stable SHA-256 hex digest of the normalized image bytes.

    Used as the suffix of the Redis cache key so a re-upload of the
    same image (e.g. a retry after a network blip) hits the cache
    instead of paying for another Anthropic round-trip.
    """
    return hashlib.sha256(data).hexdigest()


def cache_key(image_hash: str) -> str:
    return f"photo:analyze:{image_hash}"


def rate_limit_key(user_id: str) -> str:
    return f"rl:photo:{user_id}"


# ---------------------------------------------------------------------------
# Redis-backed helpers (cache + per-user rate limit)
# ---------------------------------------------------------------------------
# The route calls these instead of touching Redis directly so the
# connection-tolerant error handling lives in ONE place: if Redis is
# down or the connection drops mid-request, the helpers log and
# return a neutral "miss / under-limit" answer. The endpoint stays
# available; we just lose the cache / soft-cap.

RATE_LIMIT_WINDOW_SECONDS: int = 60
RATE_LIMIT_MAX_REQUESTS: int = 10

CACHE_NAMESPACE: str = "photo:analyze:"


async def cache_get_cached_result(redis_client, image_hash: str) -> Optional[dict[str, Any]]:
    """Look up a cached `PhotoAnalysisResult` (as a JSON dict) by
    image-hash. Returns `None` on miss, JSON-parse failure, or any
    Redis connection error."""
    try:
        raw = await redis_client.get(f"{CACHE_NAMESPACE}{image_hash}")
    except Exception as e:  # noqa: BLE001 - belt-and-braces around async I/O
        logger.warning("Photo cache lookup failed: %s", e)
        return None
    if not raw:
        return None
    try:
        parsed = json.loads(raw)
    except (TypeError, ValueError):
        return None
    return parsed


async def cache_set_cached_result(
    redis_client, image_hash: str, result: PhotoAnalysisResult, ttl_seconds: int
) -> None:
    """Store a `PhotoAnalysisResult` in Redis keyed by `image_hash`.
    Silently no-ops on any Redis error."""
    try:
        await redis_client.set(
            f"{CACHE_NAMESPACE}{image_hash}",
            result.model_dump_json(),
            ttl=ttl_seconds,
        )
    except Exception as e:  # noqa: BLE001
        logger.warning("Photo cache write failed: %s", e)


async def check_rate_limit(redis_client, user_id: str) -> bool:
    """Return True if the request is within the per-user budget, False
    if the user has exceeded `RATE_LIMIT_MAX_REQUESTS` in the last
    `RATE_LIMIT_WINDOW_SECONDS`. On any Redis error or when Redis
    isn't connected, returns True (skip the limit, let the request
    through) — mirrors the connection-tolerant pattern in
    `redis_client.py`."""
    redis = getattr(redis_client, "redis", None)
    if redis is None:
        return True
    try:
        current = await redis.incr(rate_limit_key(user_id))
    except Exception as e:  # noqa: BLE001
        logger.warning("Rate-limit incr failed: %s", e)
        return True
    if current == 1:
        try:
            await redis.expire(rate_limit_key(user_id), RATE_LIMIT_WINDOW_SECONDS)
        except Exception as e:  # noqa: BLE001
            logger.warning("Rate-limit expire failed: %s", e)
    return current <= RATE_LIMIT_MAX_REQUESTS


def new_item_id() -> str:
    """Defensive id allocator used by the route if it needs to assign
    an id to an item the model forgot to tag. UUID4 hex keeps ids
    short and unique."""
    return uuid.uuid4().hex[:12]