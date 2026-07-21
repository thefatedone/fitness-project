from fastapi import APIRouter, Depends, HTTPException, Header
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import Optional
from datetime import datetime, date
from app.core.database import get_db
from app.core.security import get_current_user, get_current_user_id
from app.models.user import User
from app.schemas.user import UserResponse, UserUpdate

router = APIRouter(prefix="/users", tags=["users"])


def recalculate_nutrition_targets(user: User) -> dict:
    """Recalculate BMR, TDEE, and nutritional targets based on user measurements."""
    if not user.current_weight or not user.height:
        return {}

    # Calculate age from date_of_birth
    age = 30 # default fallback
    if user.date_of_birth:
        today = date.today()
        age = today.year - user.date_of_birth.year - (
            (today.month, today.day) < (user.date_of_birth.month, user.date_of_birth.day)
        )

    # Mifflin-Stor equation for BMR
    if user.sex == "male":
        bmr = 10 * user.current_weight + 6.25 * user.height - 5 * age + 5
    else:
        bmr = 10 * user.current_weight + 6.25 * user.height - 5 * age - 161

    # Activity multipliers for TDEE
    activity_multipliers = {
        "sedentary": 1.2,
        "lightly_active": 1.375,
        "moderately_active": 1.55,
        "very_active": 1.725,
        "extra_active": 1.9,
    }
    multiplier = activity_multipliers.get(user.activity_level, 1.55)
    tdee = bmr * multiplier

    # Adjust calories based on primary goal
    if user.primary_goal == "lose_weight":
        daily_cal = tdee - 500
    elif user.primary_goal == "gain_muscle":
        daily_cal = tdee + 300
    else:
        daily_cal = tdee

    # Macro splits (standard 40/40/20 or adjusted)
    protein_target = user.current_weight * 1.6  # 1.6g per kg bodyweight
    fat_target = (daily_cal * 0.25) / 9  # 25% of calories from fat
    carbs_target = (daily_cal - (protein_target * 4) - (fat_target * 9)) / 4

    return {
        "bmr": round(bmr, 1),
        "tdee": round(tdee, 1),
        "daily_cal_target": round(daily_cal),
        "protein_target": round(protein_target, 1),
        "carbs_target": round(carbs_target, 1),
        "fat_target": round(fat_target, 1),
    }


@router.get("/me", response_model=UserResponse)
async def get_me(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get current user profile"""
    return UserResponse(
        id=current_user.id,
        email=current_user.email,
        full_name=current_user.full_name,
        role=current_user.role,
        phone=current_user.phone,
        date_of_birth=current_user.date_of_birth,
        sex=current_user.sex,
        height=current_user.height,
        current_weight=current_user.current_weight,
        target_weight=current_user.target_weight,
        activity_level=current_user.activity_level,
        primary_goal=current_user.primary_goal,
        dietary_preferences=current_user.dietary_preferences,
        food_allergies=current_user.food_allergies,
        weight_loss_pace=current_user.weight_loss_pace,
        bmr=current_user.bmr,
        tdee=current_user.tdee,
        daily_cal_target=current_user.daily_cal_target,
        protein_target=current_user.protein_target,
        carbs_target=current_user.carbs_target,
        fat_target=current_user.fat_target,
        is_active=current_user.is_active,
        created_at=current_user.created_at,
        profile_photo=current_user.profile_photo,
    )


@router.put("/me", response_model=UserResponse)
async def update_me(
    user_data: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Update current user profile"""
    update_data = user_data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        if field in ("dietary_preferences", "food_allergies"):
            # Pydantic normalises these to list[str] | None; persist as CSV so the
            # on-disk column shape stays unchanged.
            setattr(current_user, field, ",".join(value) if value else None)
        elif value is not None:
            if field == "date_of_birth" and isinstance(value, str):
                try:
                    value = datetime.strptime(value, "%Y-%m-%d").date()
                except ValueError:
                    raise HTTPException(status_code=400, detail="Invalid date format for date_of_birth. Use YYYY-MM-DD")
            setattr(current_user, field, value)

    # Recalculate nutrition targets if measurements changed
    if any(field in update_data for field in ['current_weight', 'height', 'activity_level', 'primary_goal', 'date_of_birth', 'sex']):
        targets = recalculate_nutrition_targets(current_user)
        for field, value in targets.items():
            setattr(current_user, field, value)

    await db.commit()
    await db.refresh(current_user)
    return current_user


@router.post("/me/photo")
async def upload_photo(
    body: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Upload profile photo (base64)"""
    image_data = body.get("image")
    if not image_data:
        raise HTTPException(status_code=400, detail="No image provided")

    # Remove data URL prefix if present
    if "," in image_data:
        image_data = image_data.split(",")[1]

    import base64
    try:
        decoded = base64.b64decode(image_data)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid base64 image")

    # File size limit (5MB)
    if len(decoded) > 5 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Image too large. Maximum size is 5MB")

    # Save to static/uploads/
    import os
    import uuid
    upload_dir = "/uploads"
    os.makedirs(upload_dir, exist_ok=True)
    filename = f"{uuid.uuid4()}.jpg"
    filepath = os.path.join(upload_dir, filename)

    # Delete old photo if exists
    if current_user.profile_photo:
        old_path = os.path.join("/uploads", os.path.basename(current_user.profile_photo))
        if os.path.exists(old_path):
            try:
                os.remove(old_path)
            except OSError:
                pass  # Ignore errors deleting old file

    with open(filepath, "wb") as f:
        f.write(decoded)

    photo_url = f"/uploads/{filename}"
    current_user.profile_photo = photo_url
    await db.commit()

    return {"url": photo_url}


@router.get("/{user_id}", response_model=UserResponse)
async def get_user(user_id: str, db: AsyncSession = Depends(get_db)):
    """Get user by ID (admin only in production)"""
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    return user
