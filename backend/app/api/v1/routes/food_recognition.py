from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.database import get_db
from app.core.config import settings
from app.core.security import get_current_user_id
from app.models.user import User
from app.models.food_log import FoodLog, WaterLog
from app.schemas.food import ReanalyzeDescriptionRequest, ManualBeverageLogRequest
from datetime import datetime, timezone
import google.generativeai as genai
import uuid
import json
import base64

router = APIRouter(prefix="/food", tags=["food-recognition"])

# Allergen categories and their related ingredients
ALLERGEN_MAP = {
    "nuts": ["almond", "almonds", "cashew", "cashews", "walnut", "walnuts", "pistachio", "pistachios",
             "pecan", "pecans", "hazelnut", "hazelnuts", "macadamia", "brazil nut", "chestnut",
             "pine nut", "pine nuts", "peanut", "peanuts", "nut", "nuts"],
    "shellfish": ["shrimp", "crab", "lobster", "crayfish", "prawn", "prawns", "scallop", "scallops",
                  "mussel", "mussels", "oyster", "oysters", "clam", "clams", "squid", "calamari",
                  "octopus", "shellfish"],
    "eggs": ["egg", "eggs", "egg white", "egg yolk", "mayonnaise", "mayo", "meringue", "albumin"],
    "soy": ["soy", "soya", "soybean", "soybeans", "tofu", "tempeh", "edamame", "miso", "soy sauce"],
    "wheat": ["wheat", "flour", "bread", "pasta", "noodle", "noodles", "spaghetti", "macaroni",
              "tortilla", "cracker", "crumbs", "breadcrumbs", "semolina", "couscous", "barley", "rye"],
    "fish": ["fish", "salmon", "tuna", "cod", "tilapia", "sardine", "sardines", "mackerel", "herring",
             "trout", "bass", "anchovy", "anchovies", "canned fish", "fish sauce"],
    "milk": ["milk", "cheese", "butter", "cream", "yogurt", "lactose", "whey", "casein", "ghee",
             "ice cream", "sour cream", "cottage cheese", "parmesan", "mozzarella", "cheddar",
             "brie", "gouda", "feta", "ricotta"],
    "gluten": ["gluten", "wheat", "barley", "rye", "oats", "flour", "bread", "pasta", "soy sauce",
               "malt", "beer"],
    "dairy": ["milk", "cheese", "butter", "cream", "yogurt", "lactose", "whey", "casein", "ghee",
              "ice cream", "sour cream", "cottage cheese", "dairy"],
    "nightshades": ["tomato", "tomatoes", "pepper", "peppers", "chili", "chilli", "jalapeño",
                    "paprika", "eggplant", "aubergine", "potato", "potatoes"],
    "fodmap": ["garlic", "onion", "leek", "shallot", "wheat", "rye", "barley", "apple", "pear",
               "mango", "watermelon", "honeydew", "milk", "soft cheese", "legume", "lentil",
               "chickpea", "cashew", "pistachio"],
    "msg": ["msg", "monosodium glutamate", "yeast extract", "hydrolyzed protein", "autolyzed yeast"],
    "sulfites": ["sulfite", "sulfites", "wine", "dried fruit", "vinegar", "molasses"],
    "sesame": ["sesame", "sesame seeds", "tahini", "halvah", "hummus", "sesame oil", "sesame paste"],
    "kiwi": ["kiwi", "kiwifruit"],
    "banana": ["banana", "bananas"],
    "citrus": ["lemon", "lime", "orange", "grapefruit", "tangerine", "mandarin", "citrus"],
    "mustard": ["mustard", "mustard seed", "mustard powder"],
    "celery": ["celery", "celeriac"],
    "pumpkin": ["pumpkin", "squash", "gourd"],
    "cabbage": ["cabbage", "brussels sprout", "broccoli", "cauliflower", "kale"],
}


def check_allergen_conflict(user_allergies: list[str], ingredients: list[str]) -> list[str]:
    """Check if any user allergy conflicts with detected ingredients. Returns list of conflicts."""
    conflicts = []
    user_allergies_lower = [a.lower().strip() for a in user_allergies]

    for allergy in user_allergies_lower:
        if not allergy:
            continue

        # Direct ingredient matches
        allergy_key = allergy.lower().strip()
        if allergy_key in ALLERGEN_MAP:
            # Check if user allergy maps to known allergens
            for ingredient in ingredients:
                ing_lower = ingredient.lower().strip()
                if ing_lower in ALLERGEN_MAP[allergy_key]:
                    conflict = f"{ingredient.title()} relates to your {allergy} allergy"
                    if conflict not in conflicts:
                        conflicts.append(conflict)
        else:
            # Fuzzy match: check if any ingredient contains the allergy word or vice versa
            for ingredient in ingredients:
                ing_lower = ingredient.lower().strip()
                if allergy_key in ing_lower or ing_lower in allergy_key:
                    if allergy_key != ing_lower:  # Don't flag exact matches already caught
                        conflict = f"{ingredient.title()} may relate to your {allergy} allergy"
                        if conflict not in conflicts:
                            conflicts.append(conflict)

    return conflicts


def _strip_markdown_fence(text: str) -> str:
    """Strip ```json ... ``` fences from a Gemini response if present.

    Gemini occasionally wraps its JSON output in markdown code
    fences even when the prompt asks it not to. We accept both the
    fenced and unfenced forms here so neither endpoint has to
    special-case the prompt-compliance behaviour.
    """
    text = text.strip()
    if text.startswith("```"):
        parts = text.split("```")
        text = parts[1] if len(parts) > 1 else parts[0]
        if text.startswith("json"):
            text = text[4:]
    return text.strip()


async def _load_user_allergies(db: AsyncSession, user_id: str) -> list[str]:
    """Async version: fetch the user's `food_allergies`, split on
    commas, return a clean list. Returns `[]` when the user has
    none stored or doesn't exist (the latter is unlikely here
    since [get_current_user_id] just authenticated them, but
    belt-and-braces).
    """
    user_result = await db.execute(select(User).where(User.id == user_id))
    user = user_result.scalar_one_or_none()
    if not user or not user.food_allergies:
        return []
    return [a.strip() for a in user.food_allergies.split(",") if a.strip()]


def _nutrition_response(
    food_log: FoodLog,
    nutrition_data: dict,
    ingredients: list[str],
    allergy_warnings: list[str],
) -> dict:
    """Build the `FoodRecognitionResult` JSON returned to the
    Flutter client. Shared by `/recognize-and-log` (which fills it
    from a freshly-inserted row) and `/reanalyze` (which fills it
    from an UPDATEd row) so the Flutter parser sees ONE stable
    shape regardless of which endpoint produced it.
    """
    response = {
        "success": True,
        "food_log_id": food_log.id,
        "nutrition": {
            "food_name": nutrition_data["food_name"],
            "calories": nutrition_data["calories"],
            "protein": nutrition_data["protein"],
            "carbs": nutrition_data["carbs"],
            "fat": nutrition_data["fat"],
            "fiber": nutrition_data.get("fiber", 0),
            "quantity": nutrition_data["quantity"],
            "unit": nutrition_data["unit"],
            "confidence": nutrition_data["confidence"],
            "description": nutrition_data.get("description", ""),
        },
        "logged_at": food_log.date.isoformat(),
        "meal_type": food_log.meal_type,
        "ingredients": ingredients,
    }
    if allergy_warnings:
        response["allergy_warning"] = allergy_warnings
        response["has_allergy_warning"] = True
    return response


async def _dual_log_beverage(
    db: AsyncSession,
    user_id: str,
    beverage_data: dict,
    ai_generated: bool,
) -> tuple[FoodLog, WaterLog]:
    """Atomically write the FoodLog + WaterLog pair for a beverage.

    Single transaction: both rows are added to the session, then a
    single `commit()` flushes them. If the commit fails (constraint
    violation, network blip, etc.) the explicit `rollback()` wipes
    any partial work — the contract is "both succeed or both roll
    back", never "calories logged but water not" or vice versa.

    Why this dual-write lives here rather than at each call site:
    the two beverage endpoints (`/recognize-beverage` high branch
    and `/log-beverage-manual`) share the exact same mapping —
    FoodLog fields (food_name / quantity=volume_ml / unit="ml" /
    fiber=0 / meal_type="drinks") and WaterLog `amount=volume_ml` —
    so the mapping logic has exactly one canonical home.

    `ai_generated` is the only field that legitimately differs
    between the two callers: True when Gemini produced the numbers
    (`/recognize-beverage` high branch), False when the user
    supplied them by hand (`/log-beverage-manual`). The downstream
    UI uses this flag to gate the "Уточнить" affordance on the
    resulting row — see `tracker_home_screen.dart`.
    """
    # Strip tzinfo so the value fits the TIMESTAMP WITHOUT TIME
    # ZONE column (asyncpg can't subtract offset-aware from
    # offset-naive datetimes). Same note as the existing food
    # endpoint.
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    volume_ml = float(beverage_data["volume_ml"])

    food_log = FoodLog(
        id=str(uuid.uuid4()),
        user_id=user_id,
        date=now,
        # Beverages get their own `meal_type` category — "drinks"
        # — rather than being lumped into "snack". The previous
        # convention (file-under-"snack") made the daily summary
        # awkward: a coffee at 3 PM and a cookie at 3 PM both
        # said "snack" even though only one of them is a drink.
        # A dedicated category lets the daily-grouping UI render
        # beverages as their own bucket (typically: water,
        # coffee/tea, sweet drinks) and the calorie / macro
        # subtotals stay meaningful. The column itself is free-
        # text (no DB-level enum), so adding a new value is a
        # pure application-code change — see also the matching
        # Flutter client (tracker_provider.addBeverageEntry
        # uses meal_type='drinks' too).
        meal_type="drinks",
        food_name=beverage_data["beverage_name"],
        calories=float(beverage_data["calories"]),
        protein=float(beverage_data["protein"]),
        carbs=float(beverage_data["carbs"]),
        fat=float(beverage_data["fat"]),
        # Beverages don't carry meaningful dietary fiber; we set 0
        # explicitly rather than letting `None` leak through.
        fiber=0,
        quantity=volume_ml,
        unit="ml",
        ai_generated=ai_generated,
    )
    water_log = WaterLog(
        id=str(uuid.uuid4()),
        user_id=user_id,
        # WaterLog.amount is `Integer` per the model schema; coerce
        # defensively so a `volume_ml` like `330.5` (the model
        # sometimes returns non-integer volumes for "partial glass"
        # interpretations) gets rounded down to the nearest ml,
        # matching what the UI already does for water quick-pick
        # chips in `_AddWaterSheet`.
        amount=int(volume_ml),
        date=now,
    )
    db.add(food_log)
    db.add(water_log)
    try:
        await db.commit()
    except Exception as e:
        # Both rows added but neither persisted. The rollback
        # restores the session to a clean state so a subsequent
        # endpoint call (or the same call's retry) starts from
        # scratch.
        await db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"Failed to log beverage: {str(e)}",
        )
    await db.refresh(food_log)
    await db.refresh(water_log)
    return food_log, water_log


def _beverage_response(
    food_log: FoodLog,
    water_log: WaterLog,
    beverage_data: dict,
    allergy_warnings: list[str],
) -> dict:
    """Build the auto-logged response for the beverage endpoints.

    Used by BOTH `/recognize-beverage`'s high-confidence branch
    AND `/log-beverage-manual` so the Flutter client sees one
    stable shape for "I just committed a beverage to the log" —
    only the `suggestion`-only shape (returned when confidence is
    medium/low) lives at the call site, because it's a
    single-shot dict literal that's awkward to lift to a helper.
    """
    response = {
        "success": True,
        "auto_logged": True,
        "food_log_id": food_log.id,
        "water_log_id": water_log.id,
        "nutrition": {
            "beverage_name": beverage_data["beverage_name"],
            "volume_ml": beverage_data["volume_ml"],
            "calories": beverage_data["calories"],
            "protein": beverage_data["protein"],
            "carbs": beverage_data["carbs"],
            "fat": beverage_data["fat"],
            "sugar_g": beverage_data["sugar_g"],
        },
        "confidence": beverage_data.get("confidence", "high"),
        "logged_at": food_log.date.isoformat(),
    }
    if allergy_warnings:
        response["allergy_warning"] = allergy_warnings
        response["has_allergy_warning"] = True
    return response


@router.post("/recognize-and-log")
async def recognize_and_log_food(
    meal_type: str = "snack",
    file: UploadFile = File(...),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    # Validate file type
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File must be an image")

    # File size limit (10MB)
    contents = await file.read()
    if len(contents) > 10 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="File too large. Maximum size is 10MB")

    # Read image
    base64_image = base64.b64encode(contents).decode("utf-8")

    # Configure Gemini
    genai.configure(api_key=settings.GEMINI_API_KEY)
    model = genai.GenerativeModel("gemini-2.5-flash-lite")

    # Prompt for Gemini - updated to extract ingredients
    prompt = """Analyze this food image and provide nutritional estimates AND a detailed list of ingredients.
Respond with ONLY valid JSON, no markdown or explanation:
{
  "food_name": "name of the food",
  "quantity": 1,
  "unit": "serving",
  "calories": 0,
  "protein": 0,
  "carbs": 0,
  "fat": 0,
  "fiber": 0,
  "confidence": "high",
  "description": "brief description",
  "ingredients": ["ingredient1", "ingredient2", "ingredient3"]
}
Rules:
- All numeric fields must be actual numbers (not strings)
- confidence must be "high", "medium", or "low"
- Never return null values — estimate if unsure
- ingredients must be an array of individual food items detected in the image (e.g. ["salmon", "almonds", "spinach", "olive oil"])
- List ALL detectable ingredients, especially common allergens (nuts, milk, eggs, wheat, soy, fish, shellfish, sesame)
- Be specific with ingredient names (e.g. "almonds" not "nuts", "tofu" not "soy")"""

    # Call Gemini
    try:
        image_part = {"mime_type": file.content_type, "data": base64_image}
        response = model.generate_content([prompt, image_part])
        nutrition_data = json.loads(_strip_markdown_fence(response.text))
    except json.JSONDecodeError:
        raise HTTPException(status_code=422, detail="Could not parse nutritional data from image")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Gemini API error: {str(e)}")

    # Fetch user's food allergies + check for conflicts against the
    # recognized ingredients. Same logic as `/reanalyze` — see
    # `_load_user_allergies` for why the lookup shape is identical.
    user_allergies = await _load_user_allergies(db, user_id)
    ingredients = nutrition_data.get("ingredients", [])
    allergy_warnings = (
        check_allergen_conflict(user_allergies, ingredients)
        if user_allergies and ingredients
        else []
    )

    # Log to database — strip tzinfo so the value fits the
    # TIMESTAMP WITHOUT TIME ZONE column (asyncpg can't subtract
    # offset-aware from offset-naive datetimes).
    food_log = FoodLog(
        id=str(uuid.uuid4()),
        user_id=user_id,
        date=datetime.now(timezone.utc).replace(tzinfo=None),
        meal_type=meal_type,
        food_name=nutrition_data["food_name"],
        calories=float(nutrition_data["calories"]),
        protein=float(nutrition_data["protein"]),
        carbs=float(nutrition_data["carbs"]),
        fat=float(nutrition_data["fat"]),
        fiber=float(nutrition_data.get("fiber", 0)),
        quantity=float(nutrition_data["quantity"]),
        unit=nutrition_data["unit"],
        ai_generated=True,
    )
    db.add(food_log)
    await db.commit()
    await db.refresh(food_log)

    return _nutrition_response(food_log, nutrition_data, ingredients, allergy_warnings)


@router.post("/{food_id}/reanalyze")
async def reanalyze_food(
    food_id: str,
    request: ReanalyzeDescriptionRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Re-estimate macros for an existing food log row using the
    user's EDITED text description (no image).

    Workflow: the photo-recognition flow auto-logs a row, then the
    Flutter client offers an "edit & re-analyze" path — typically
    when the AI got the food wrong (e.g. misread pasta as a salad)
    or the user wants to add a previously-omitted ingredient
    (butter, parmesan). This endpoint owns that second pass.

    Why this endpoint exists rather than a `PUT /tracker/food/{id}`:
    the user isn't supplying macros themselves — they supply a
    text correction, and we still want Gemini to do the
    estimation. Re-running through the same model + prompt
    contract keeps the "AI-estimated" provenance (`ai_generated`
    stays True) and the same allergen-warning semantics.

    Why UPDATE in place rather than INSERT a new row: a correction
    is not a new meal. Keeping the same `id`, `date`, `meal_type`
    means the daily food log doesn't duplicate, the
    pull-to-refresh list shows the corrected values immediately,
    and any external analytics that already counted the row are
    not double-counted.
    """
    # Fetch + ownership-check the row. We 404 in BOTH the
    # "doesn't exist" and "exists but belongs to another user"
    # cases — never leak existence to non-owners, even by error-
    # message timing. The single SQL trip keeps this cheap.
    result = await db.execute(select(FoodLog).where(FoodLog.id == food_id))
    food_log = result.scalar_one_or_none()
    if food_log is None or food_log.user_id != user_id:
        raise HTTPException(status_code=404, detail="Food log not found")

    # Configure Gemini — same model/version as `/recognize-and-log`
    # so the two code paths share a contract. Re-configuring on
    # every request is a no-op for SDK state and avoids needing a
    # module-level mutable.
    genai.configure(api_key=settings.GEMINI_API_KEY)
    model = genai.GenerativeModel("gemini-2.5-flash-lite")

    # TEXT-ONLY prompt — no image_part, ever. The JSON response
    # shape is byte-identical to the photo-recognition prompt (same
    # field names, same rule list) so the same Python parser
    # works on both. We feed the model the existing `food_name`
    # as context (so it can keep the same overall identity, e.g.
    # "spaghetti bolognese" stays "spaghetti bolognese" rather
    # than drifting to "pasta with meat sauce") plus the user's
    # edited description, which carries the actual correction.
    prompt = f"""Update nutritional estimates and ingredient list based on a user's revised text description of a food.
The original estimate was generated from a photo; the user has refined the description to correct it.
Respond with ONLY valid JSON, no markdown or explanation:
{{
  "food_name": "name of the food",
  "quantity": 1,
  "unit": "serving",
  "calories": 0,
  "protein": 0,
  "carbs": 0,
  "fat": 0,
  "fiber": 0,
  "confidence": "high",
  "description": "brief description",
  "ingredients": ["ingredient1", "ingredient2", "ingredient3"]
}}
Original food name: {food_log.food_name}
User's updated description: {request.description}
Rules:
- All numeric fields must be actual numbers (not strings)
- confidence must be "high", "medium", or "low"
- Never return null values — estimate if unsure
- ingredients must be an array of individual food items inferred from the description (e.g. ["salmon", "almonds", "spinach", "olive oil"])
- List ALL detectable ingredients, especially common allergens (nuts, milk, eggs, wheat, soy, fish, shellfish, sesame)
- Be specific with ingredient names (e.g. "almonds" not "nuts", "tofu" not "soy")"""

    # Same parse flow as `/recognize-and-log`: strip optional
    # markdown fences, then `json.loads`. Same error mapping:
    #   * parse failure → 422 (the model's output was malformed,
    #     not the request)
    #   * any other Gemini error → 500 (transport / quota / etc.)
    try:
        gemini_response = model.generate_content(prompt)
        nutrition_data = json.loads(_strip_markdown_fence(gemini_response.text))
    except json.JSONDecodeError:
        raise HTTPException(
            status_code=422,
            detail="Could not parse nutritional data from text description",
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Gemini API error: {str(e)}")

    # Re-run the allergen check against the NEW ingredients. The
    # user may have corrected away from an allergen ("actually
    # it's soy milk, not dairy") or introduced one ("oh, I forgot
    # to mention the peanut sauce"), and either direction
    # matters — the warning list is recomputed from scratch, not
    # diffed against the previous one.
    user_allergies = await _load_user_allergies(db, user_id)
    ingredients = nutrition_data.get("ingredients", [])
    allergy_warnings = (
        check_allergen_conflict(user_allergies, ingredients)
        if user_allergies and ingredients
        else []
    )

    # UPDATE the row in place. We deliberately do NOT touch `id`,
    # `user_id`, `date`, `meal_type`, `ai_generated`, or `created_at`
    # — those are all invariants of "this is the food I ate at
    # this meal on this day"; a correction doesn't move the entry.
    # We DO overwrite the AI-estimated fields (the whole point of
    # the call) and `ai_generated` stays True because the new
    # numbers are still AI-estimated, just on a better prompt.
    food_log.food_name = nutrition_data["food_name"]
    food_log.calories = float(nutrition_data["calories"])
    food_log.protein = float(nutrition_data["protein"])
    food_log.carbs = float(nutrition_data["carbs"])
    food_log.fat = float(nutrition_data["fat"])
    food_log.fiber = float(nutrition_data.get("fiber", 0))
    food_log.quantity = float(nutrition_data["quantity"])
    food_log.unit = nutrition_data["unit"]

    await db.commit()
    await db.refresh(food_log)

    # Same response shape as `/recognize-and-log` so the Flutter
    # `FoodRecognitionResult` parser doesn't branch on which
    # endpoint it heard from. The `logged_at` / `meal_type` come
    # from the *original* row (unchanged), and the ingredients /
    # nutrition / allergy_warning fields reflect the new values.
    return _nutrition_response(food_log, nutrition_data, ingredients, allergy_warnings)


@router.post("/recognize-beverage")
async def recognize_beverage(
    file: UploadFile = File(...),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """AI beverage recognition with confidence-gated auto-logging.

    Workflow:
      1. Upload a photo of the user's drink.
      2. Gemini identifies the beverage, estimates volume from
         container cues, and returns calories/macros/sugar for the
         estimated volume (NOT per 100ml).
      3. If `confidence == "high"` AND the beverage is visually
         unambiguous (plain still water, plain carbonated water —
         see the prompt's confidence-calibration rules), this
         endpoint dual-writes a `FoodLog` (calories/macros) AND a
         `WaterLog` (volume) in a single atomic transaction and
         returns `auto_logged: true` with both row ids.
      4. If `confidence` is `medium` or `low` (any colored, branded,
         or opaque beverage), this endpoint does NOT write to the
         database. It returns `auto_logged: false` with a
         `suggestion` payload — the client renders that as a
         pre-filled form the user can confirm/edit before POSTing
         to `/log-beverage-manual`.

    Why the asymmetric write/no-write contract: an automatic
    "I drank a Coke" entry written with confidence "low" would
    silently embed a wrong calorie count in the user's daily log,
    where the UI presents numbers as authoritative. By reserving
    auto-logging for the only two cases that ARE visually
    unambiguous (plain water + plain sparkling water), the
    trust-the-default path is also the low-error path. Everything
    else — including the "high" tag the model occasionally wants
    to assign to colored beverages — flows through manual
    confirmation.
    """
    # Validate file type
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File must be an image")

    # File size limit (10MB) — same as `/recognize-and-log`.
    contents = await file.read()
    if len(contents) > 10 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="File too large. Maximum size is 10MB")

    base64_image = base64.b64encode(contents).decode("utf-8")

    # Configure Gemini — same model + per-request re-configure
    # pattern as the existing endpoints. SDK state is idempotent.
    genai.configure(api_key=settings.GEMINI_API_KEY)
    model = genai.GenerativeModel("gemini-2.5-flash-lite")

    # Beverage-specific prompt. Two design points worth calling out:
    #
    #   * Macros are for the ESTIMATED VOLUME (not per 100ml). This
    #     matches the user's mental model — they want to know how
    #     many calories were in the *drink they actually had*, not
    #     a normalised rate.
    #
    #   * The confidence-calibration block is deliberately
    #     conservative. Plain still water and plain sparkling water
    #     are visually unambiguous (clear, no color, no branding),
    #     so "high" is honest there. For everything else — sodas,
    #     juices, coffee, tea, alcohol, milk-based drinks — visual
    #     identification can't reliably distinguish brands or
    #     formulations ("brown fizzy liquid in a glass" could be
    #     any of several colas with materially different calorie
    #     counts), so "medium"/"low" forces the user into the
    #     confirmation flow rather than silently embedding a
    #     confident-but-wrong calorie count.
    prompt = """Analyze this beverage image and identify what the user is drinking.
Respond with ONLY valid JSON, no markdown or explanation:
{
  "beverage_name": "name of the beverage",
  "volume_ml": 0,
  "calories": 0,
  "protein": 0,
  "carbs": 0,
  "fat": 0,
  "sugar_g": 0,
  "confidence": "high",
  "description": "brief description of visual cues"
}

Visual cues to consider:
- Color (clear, amber, brown, white, green, etc.)
- Carbonation (visible bubbles or still)
- Container type (can, glass, bottle, cup, mug, etc.)
- Branding visible on the container
- Ice, garnish, milk/foam layer

Volume estimation (in millilitres):
- Standard drinking glass: ~250 ml
- Small glass: ~150 ml
- Large glass / pint: ~400-500 ml
- Standard can: ~330 ml
- Standard small bottle: ~250-330 ml
- Standard large bottle: ~500 ml
- Mug: ~250-350 ml
- To-go cup: ~250-500 ml

Pick the closest reasonable estimate based on container type and
fill level. Return the volume in ml for the visible liquid only.

Calories and macros MUST be for the ESTIMATED VOLUME (not per 100 ml).

Sugar: include the total grams of sugar for the estimated volume.
Sugar content is the primary nutritionally relevant fact for
beverages.

Confidence calibration (CRITICAL — be honest, not optimistic):
- confidence = "high" ONLY when visually certain:
    - Plain still water (clear, no color, no branding): ALWAYS "high", 0 calories
    - Plain sparkling/carbonated water (clear, no color, no branding): ALWAYS "high", 0 calories
    - These are the only two cases where visual identification is truly unambiguous.
- confidence = "medium" or "low" for everything else:
    - Any colored, branded, or opaque beverage (soda, juice, coffee, tea, alcohol, milk-based drinks)
    - Exact brand/formulation cannot be reliably determined from appearance alone
      (e.g. "brown fizzy liquid in a glass" could be any of several cola brands with different calorie counts)
- Be honest and conservative — guessing "high" to seem more helpful would mislead the user
  about the actual nutritional accuracy of the estimate.

Rules:
- All numeric fields must be actual numbers (not strings)
- Never return null values — estimate if unsure
- beverage_name should be a short, human-readable label (e.g. "Sparkling water", "Cola", "Whole milk", "Black coffee")
- description should briefly describe the visual cues you used (1-2 sentences)"""

    # Same parse flow as the other endpoints: strip optional
    # markdown fences, then `json.loads`. Same error mapping:
    #   * parse failure → 422 (the model's output was malformed)
    #   * any other Gemini error → 500 (transport / quota / etc.)
    try:
        image_part = {"mime_type": file.content_type, "data": base64_image}
        response = model.generate_content([prompt, image_part])
        beverage_data = json.loads(_strip_markdown_fence(response.text))
    except json.JSONDecodeError:
        raise HTTPException(status_code=422, detail="Could not parse beverage data from image")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Gemini API error: {str(e)}")

    confidence = beverage_data.get("confidence", "low")

    # Low / medium confidence: NO database writes. Return a
    # suggestion-only payload so the client can render a
    # pre-filled manual-confirmation form. The user reviews /
    # edits the values, then POSTs to `/log-beverage-manual` if
    # they accept.
    if confidence != "high":
        return {
            "success": True,
            "auto_logged": False,
            "suggestion": {
                "beverage_name": beverage_data["beverage_name"],
                "volume_ml": beverage_data["volume_ml"],
                "calories": beverage_data["calories"],
                "protein": beverage_data["protein"],
                "carbs": beverage_data["carbs"],
                "fat": beverage_data["fat"],
                "sugar_g": beverage_data["sugar_g"],
                "confidence": confidence,
                "description": beverage_data.get("description", ""),
            },
        }

    # High confidence: dual-write FoodLog + WaterLog atomically.
    # Allergen check on the beverage name for consistency with
    # the food-recognition endpoint (beverages are less likely to
    # trigger it but we run it anyway so the UI's
    # "has_allergy_warning" badge logic stays uniform). We pass
    # only the `beverage_name` as the ingredients list — the
    # description is prose and would create false positives via
    # the fuzzy substring matcher.
    user_allergies = await _load_user_allergies(db, user_id)
    allergy_warnings = (
        check_allergen_conflict(user_allergies, [beverage_data["beverage_name"]])
        if user_allergies
        else []
    )

    food_log, water_log = await _dual_log_beverage(
        db=db,
        user_id=user_id,
        beverage_data=beverage_data,
        ai_generated=True,
    )

    return _beverage_response(food_log, water_log, beverage_data, allergy_warnings)


@router.post("/log-beverage-manual")
async def log_beverage_manual(
    request: ManualBeverageLogRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """User-confirmed beverage log entry.

    Counterpart to `/recognize-beverage`'s medium/low-confidence
    branch: the AI proposed a suggestion, the user reviewed it
    (optionally editing name / volume / macros), and POSTs the
    final values here.

    No Gemini round-trip — the user has vouched for the numbers.
    Identical dual-write to the photo endpoint's high-confidence
    branch (FoodLog + WaterLog in one transaction, meal_type
    "snack", volume mapped to both `quantity` and `amount`), with
    `ai_generated: False` to reflect user-vetted provenance —
    this matters because the home screen's "Уточнить" edit
    affordance only appears on `aiGenerated == True` rows, and a
    user-typed entry shouldn't show that affordance (the user
    already produced the values, there's nothing for the AI to
    re-estimate).

    Response shape is byte-identical to the auto-logged branch so
    the Flutter client can treat both code paths identically after
    the fact.
    """
    # Build the same internal `beverage_data` dict shape that the
    # dual-write helper expects. `confidence: "high"` is
    # semantically the right value here — the user has confirmed,
    # so the result is now "definitive" by definition — and keeps
    # the response field shape identical across endpoints.
    beverage_data = {
        "beverage_name": request.beverage_name,
        "volume_ml": request.volume_ml,
        "calories": request.calories,
        "protein": request.protein,
        "carbs": request.carbs,
        "fat": request.fat,
        "sugar_g": request.sugar_g,
        "confidence": "high",
    }

    # No allergen check on this path: the user is the source of
    # truth for the beverage they typed. If they typed "milk"
    # while allergic to milk, they're aware — running the
    # check-allergen-conflict step here would add noise (the UI
    # would show a "⚠️ Milk relates to your milk allergy"
    # banner on every manual entry) without providing useful
    # information.

    food_log, water_log = await _dual_log_beverage(
        db=db,
        user_id=user_id,
        beverage_data=beverage_data,
        ai_generated=False,
    )

    return _beverage_response(food_log, water_log, beverage_data, [])


@router.post("/verify-beverage-name")
async def verify_beverage_name(
    claimed_name: str = Form(
        ...,
        min_length=1,
        description=(
            "The user-typed beverage name to cross-check against the "
            "image. Required — an empty claim is meaningless to verify."
        ),
    ),
    file: UploadFile = File(...),
    user_id: str = Depends(get_current_user_id),
):
    """Cross-check whether a beverage image plausibly matches the
    user-claimed name.

    Workflow: the Flutter UI's manual-confirmation form receives
    the AI's `suggestion` payload (beverage name + macros from
    `/recognize-beverage`'s medium/low-confidence branch). Before
    the user taps "Подтвердить и сохранить", they may also edit
    the name. This endpoint is the "is this edited name actually
    what the photo shows?" sanity check — `plausible=true` lets
    the UI proceed (or just silently — currently no UI hooks
    into it), `plausible=false` lets the UI surface a corrected
    hint via the `detected_instead` field.

    No DB writes — the endpoint is a read-only verification, not
    a commit. The actual commit happens via
    `/log-beverage-manual` once the user confirms the final
    values.

    Response shape:
        {
          "plausible": bool,
          "detected_instead": str | null
        }

    `detected_instead` is `null` when `plausible == true` (no
    counter-suggestion); a short string like `"green tea"` /
    `"orange juice"` / `"sparkling water"` when `plausible ==
    false` so the UI can prompt the user with the model's best
    guess of what the image actually shows.
    """
    # Validate file type — same as the other endpoints.
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File must be an image")

    # File size limit (10MB) — same as the other endpoints.
    contents = await file.read()
    if len(contents) > 10 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="File too large. Maximum size is 10MB")

    base64_image = base64.b64encode(contents).decode("utf-8")

    # Configure Gemini — same model + per-request re-configure
    # pattern as the existing endpoints. SDK state is idempotent.
    genai.configure(api_key=settings.GEMINI_API_KEY)
    model = genai.GenerativeModel("gemini-2.5-flash-lite")

    # Verification prompt. Three design points worth calling out:
    #
    #   * "Plausibly" is deliberately weaker than "definitely" —
    #     the model is asked whether the image is *consistent*
    #     with the claimed name, not whether it proves the
    #     claim. A brown fizzy liquid in a generic glass could
    #     plausibly be any of several colas, so we don't want
    #     the model to reject those — we want it to surface
    #     what it actually sees (for the `detected_instead`
    #     field) when the claim is wrong.
    #
    #   * The `detected_instead` field is the actionable signal
    #     for the Flutter UI: when `plausible == false`, the UI
    #     can show "this looks like {detected_instead} instead of
    #     {claimed_name}?" rather than just "no", giving the
    #     user a concrete next-step suggestion.
    #
    #   * The DETERMINISTIC WATER RULE (placed FIRST, with
    #     explicit priority labelling) hard-codes the only
    #     case where the general fuzzy-match rule would mislead
    #     the user: a "water" claim over a photo of any visible
    #     color. Water is *definitionally* clear/colorless/
    #     transparent, so the model has zero legitimate
    #     ambiguity here — any visible color (brown, dark,
    #     yellow, orange, red, green, etc.) or opacity must
    #     produce `plausible=false` with high certainty. This
    #     is exactly the failure mode reported in production
    #     (a Coca-Cola photo saved as "Вода"), where the model
    #     was happy to call a brown fizzy liquid "consistent
    #     with water" because it had no explicit anchor for the
    #     case. Combined with `temperature=0` on this specific
    #     call (see below), the judgment is now deterministic
    #     rather than sampled.
    prompt = f"""Does this image plausibly show a beverage called '{claimed_name}'?
Consider color, packaging, branding, and what's visible in the container.
Respond with ONLY valid JSON, no markdown or explanation:
{{"plausible": true|false, "detected_instead": "string or null"}}

DETERMINISTIC WATER RULE — HIGHEST PRIORITY, OVERRIDES THE GENERAL RULES BELOW:
If the claimed name is water, still water, sparkling water, mineral water, or a direct translation of these (e.g. Russian 'вода', French 'eau', Spanish 'agua', German 'Wasser') in ANY language, the photographed liquid MUST appear clear, colorless, and transparent for plausible=true. ANY visible color (brown, dark, yellow, orange, red, green, blue, etc.) or opacity makes plausible=false with HIGH CERTAINTY — no ambiguity should be allowed for this specific case since water's visual signature is unambiguous.

General rules:
- `plausible` should be true when the image is consistent with the claimed name (any of several brands is fine — we want a fuzzy match).
- `plausible` should be false when the image clearly shows a DIFFERENT beverage (e.g. claimed "Cola" but image shows a green liquid).
- `detected_instead` should be a short string describing what the image actually shows (e.g. "green tea", "orange juice", "sparkling water") when `plausible` is false; null when `plausible` is true.
- Never return null `plausible` — always true or false."""

    # Same parse flow as the other endpoints: strip optional
    # markdown fences, then `json.loads`. Same error mapping:
    #   * parse failure → 422 (the model's output was malformed,
    #     not the request)
    #   * any other Gemini error → 500 (transport / quota / etc.)
    #
    # `generation_config={"temperature": 0}` is passed PER-CALL
    # (not on `GenerativeModel` construction) so the other
    # endpoints in this file — which benefit from sampling for
    # ingredient-name creativity — keep their default temperature.
    # Determinism matters most for THIS prompt because it's the
    # one the user sees as the gate on a save action: sampling
    # here would mean the same photo + claim could plausibly
    # toggle between two SnackBars across calls, which would be a
    # confusing UX bug.
    try:
        image_part = {"mime_type": file.content_type, "data": base64_image}
        response = model.generate_content(
            [prompt, image_part],
            generation_config={"temperature": 0},
        )
        verification = json.loads(_strip_markdown_fence(response.text))
    except json.JSONDecodeError:
        raise HTTPException(
            status_code=422,
            detail="Could not parse verification result from image",
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Gemini API error: {str(e)}")

    # Defensive normalisation: the model occasionally returns a
    # `detected_instead` of `""` when it could have written
    # `null`. Treat empty-string and missing as null so the UI
    # always sees a clean `string | null` shape (the Flutter
    # Dart-side parser assumes exactly that).
    detected = verification.get("detected_instead")
    if isinstance(detected, str) and detected.strip() == "":
        detected = None

    return {
        "plausible": bool(verification.get("plausible", False)),
        "detected_instead": detected,
    }
