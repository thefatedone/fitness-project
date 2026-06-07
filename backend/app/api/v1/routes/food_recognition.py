from fastapi import APIRouter, Depends, UploadFile, File, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.database import get_db
from app.core.config import settings
from app.core.security import get_current_user_id
from app.models.user import User
from app.models.food_log import FoodLog
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
        response_text = response.text.strip()
        if response_text.startswith("```"):
            parts = response_text.split("```")
            response_text = parts[1] if len(parts) > 1 else parts[0]
            if response_text.startswith("json"):
                response_text = response_text[4:]
        nutrition_data = json.loads(response_text.strip())
    except json.JSONDecodeError:
        raise HTTPException(status_code=422, detail="Could not parse nutritional data from image")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Gemini API error: {str(e)}")

    # Fetch user's food allergies from database
    user_result = await db.execute(select(User).where(User.id == user_id))
    user = user_result.scalar_one_or_none()
    user_allergies = []
    if user and user.food_allergies:
        user_allergies = [a.strip() for a in user.food_allergies.split(",") if a.strip()]

    # Check for allergen conflicts
    ingredients = nutrition_data.get("ingredients", [])
    allergy_warnings = []
    if user_allergies and ingredients:
        allergy_warnings = check_allergen_conflict(user_allergies, ingredients)

    # Log to database
    food_log = FoodLog(
        id=str(uuid.uuid4()),
        user_id=user_id,
        date=datetime.now(timezone.utc),
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
        "meal_type": meal_type,
        "ingredients": ingredients,
    }

    if allergy_warnings:
        response["allergy_warning"] = allergy_warnings
        response["has_allergy_warning"] = True

    return response
