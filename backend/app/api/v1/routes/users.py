from fastapi import APIRouter, Depends, HTTPException, Header
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import Optional
from datetime import datetime
from app.core.database import get_db
from app.models.user import User
from app.schemas.user import UserResponse, UserUpdate

router = APIRouter(prefix="/users", tags=["users"])


def get_current_user_id(token: str = None) -> Optional[str]:
    """Extract user ID from JWT token"""
    if not token:
        return None
    try:
        from jose import jwt
        from app.core.config import settings
        payload = jwt.decode(token, settings.JWT_SECRET, options={"verify_signature": False})
        return payload.get("sub")
    except Exception:
        return None


def require_auth(token: str = None) -> str:
    user_id = get_current_user_id(token)
    if not user_id:
        raise HTTPException(status_code=401, detail="Not authenticated")
    return user_id


def recalculate_nutrition_targets(user: User) -> dict:
    """Recalculate BMR, TDEE, and nutritional targets based on user measurements"""
    if not user.current_weight or not user.height:
        return {}

    # Mifflin-Stor equation for BMR
    if user.sex == "male":
        bmr = 10 * user.current_weight + 6.25 * user.height - 5 * 30 + 5
    else:
        bmr = 10 * user.current_weight + 6.25 * user.height - 5 * 30 - 161

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
    authorization: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db)
):
    """Get current user profile"""
    token = authorization.replace("Bearer ", "") if authorization else None
    user_id = get_current_user_id(token)

    if not user_id:
        raise HTTPException(status_code=401, detail="Not authenticated")

    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    return UserResponse(
        id=user.id,
        email=user.email,
        full_name=user.full_name,
        role=user.role,
        phone=user.phone,
        date_of_birth=user.date_of_birth,
        sex=user.sex,
        height=user.height,
        current_weight=user.current_weight,
        target_weight=user.target_weight,
        activity_level=user.activity_level,
        primary_goal=user.primary_goal,
        dietary_preferences=user.dietary_preferences,
        food_allergies=user.food_allergies,
        weight_loss_pace=user.weight_loss_pace,
        bmr=user.bmr,
        tdee=user.tdee,
        daily_cal_target=user.daily_cal_target,
        protein_target=user.protein_target,
        carbs_target=user.carbs_target,
        fat_target=user.fat_target,
        is_active=user.is_active,
        created_at=user.created_at,
    )


@router.put("/me", response_model=UserResponse)
async def update_me(
    user_data: UserUpdate,
    authorization: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db)
):
    """Update current user profile"""
    token = authorization.replace("Bearer ", "") if authorization else None
    user_id = get_current_user_id(token)

    if not user_id:
        raise HTTPException(status_code=401, detail="Not authenticated")

    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    update_data = user_data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        if value is not None:
            if field == "date_of_birth" and isinstance(value, str):
                value = datetime.strptime(value, "%Y-%m-%d")
            if field == "dietary_preferences" and isinstance(value, list):
                value = ",".join(value)
            if field == "food_allergies" and isinstance(value, list):
                value = ",".join(value)
            setattr(user, field, value)

    # Recalculate nutrition targets if measurements changed
    if any(field in update_data for field in ['current_weight', 'height', 'activity_level', 'primary_goal']):
        targets = recalculate_nutrition_targets(user)
        for field, value in targets.items():
            setattr(user, field, value)

    await db.commit()
    await db.refresh(user)
    return user


@router.get("/{user_id}", response_model=UserResponse)
async def get_user(user_id: str, db: AsyncSession = Depends(get_db)):
    """Get user by ID (admin only in production)"""
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    return user