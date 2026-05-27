from fastapi import APIRouter, Depends, UploadFile, File, HTTPException, Header
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_db
from app.core.config import settings
from app.models.user import User
from app.models.food_log import FoodLog
from datetime import datetime
import google.generativeai as genai
import uuid
import json
import base64

router = APIRouter(prefix="/food", tags=["food-recognition"])


def get_current_user_id(authorization: str = None) -> str | None:
    """Extract user ID from JWT token"""
    if not authorization or not authorization.startswith("Bearer "):
        return None
    token = authorization.replace("Bearer ", "")
    try:
        from jose import jwt
        payload = jwt.decode(token, settings.JWT_SECRET, options={"verify_signature": False})
        return payload.get("sub")
    except Exception:
        return None


@router.post("/recognize-and-log")
async def recognize_and_log_food(
    meal_type: str = "snack",
    file: UploadFile = File(...),
    authorization: str = Header(None),
    db: AsyncSession = Depends(get_db)
):
    user_id = get_current_user_id(authorization)
    if not user_id:
        raise HTTPException(status_code=401, detail="Not authenticated")

    # Validate file type
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File must be an image")

    # Read image
    image_data = await file.read()
    base64_image = base64.b64encode(image_data).decode("utf-8")

    # Configure Gemini
    genai.configure(api_key=settings.GEMINI_API_KEY)
    model = genai.GenerativeModel("gemini-2.5-flash-lite")

    # Prompt for Gemini
    prompt = """Analyze this food image and provide nutritional estimates.
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
  "description": "brief description"
}
Rules:
- All numeric fields must be actual numbers (not strings)
- confidence must be "high", "medium", or "low"
- Never return null values — estimate if unsure"""

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

    # Log to database
    food_log = FoodLog(
        id=str(uuid.uuid4()),
        user_id=user_id,
        date=datetime.utcnow(),
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

    return {
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
    }
