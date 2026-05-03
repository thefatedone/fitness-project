from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.database import get_db
from app.core.security import decode_token
from app.models.user import User
from app.schemas.user import UserResponse, UserProfileUpdate
from app.services.nutrition_service import (
    calculate_age, calculate_bmr, calculate_tdee, calculate_targets
)
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import json

router = APIRouter()
security = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db)
) -> User:
    payload = decode_token(credentials.credentials)
    if not payload:
        raise HTTPException(status_code=401, detail="Invalid token")
    result = await db.execute(select(User).where(User.id == payload.get("sub")))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    return user


@router.get("/me", response_model=UserResponse)
async def get_me(current_user: User = Depends(get_current_user)):
    return current_user


@router.put("/me", response_model=UserResponse)
async def update_me(
    data: UserProfileUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    for field, value in data.model_dump(exclude_none=True).items():
        setattr(current_user, field, value)

    # Recalculate nutrition targets if we have enough data
    if all([
        current_user.current_weight,
        current_user.height,
        current_user.date_of_birth,
        current_user.sex,
        current_user.activity_level,
        current_user.primary_goal,
    ]):
        age = calculate_age(current_user.date_of_birth)
        bmr = calculate_bmr(
            current_user.current_weight,
            current_user.height,
            age,
            current_user.sex
        )
        tdee = calculate_tdee(bmr, current_user.activity_level)
        targets = calculate_targets(
            tdee,
            current_user.primary_goal,
            current_user.weight_loss_pace or 0.5
        )
        current_user.bmr = bmr
        current_user.tdee = tdee
        current_user.daily_cal_target = targets["calories"]
        current_user.protein_target = targets["protein"]
        current_user.carbs_target = targets["carbs"]
        current_user.fat_target = targets["fat"]
        current_user.onboarding_step = 4

    await db.commit()
    await db.refresh(current_user)
    return current_user


@router.get("/admin/users")
async def admin_get_users(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    if current_user.role != "ADMIN":
        raise HTTPException(status_code=403, detail="Admin only")
    result = await db.execute(
        select(User).order_by(User.created_at.desc())
    )
    users = result.scalars().all()
    return [
        {
            "id": u.id,
            "name": u.name,
            "email": u.email,
            "phone": u.phone,
            "role": u.role,
            "is_active": u.is_active,
            "primary_goal": u.primary_goal,
            "onboarding_step": u.onboarding_step,
            "created_at": u.created_at.isoformat() if u.created_at else None,
            "height": u.height,
            "current_weight": u.current_weight,
            "daily_cal_target": u.daily_cal_target,
            "activity_level": u.activity_level,
        }
        for u in users
    ]


@router.put("/admin/users/{user_id}")
async def admin_update_user(
    user_id: str,
    is_active: bool,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    if current_user.role != "ADMIN":
        raise HTTPException(status_code=403, detail="Admin only")
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.is_active = is_active
    await db.commit()
    return {"message": "Updated", "is_active": is_active}


@router.delete("/admin/users/{user_id}")
async def admin_delete_user(
    user_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    if current_user.role != "ADMIN":
        raise HTTPException(status_code=403, detail="Admin only")
    if user_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot delete yourself")
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    await db.delete(user)
    await db.commit()
    return {"message": "Deleted"}