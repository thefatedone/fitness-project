from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.database import get_db
from app.models.user import User
from app.schemas.user import UserResponse, UserUpdate

router = APIRouter(prefix="/users", tags=["users"])


def get_current_user_id(token: str = None) -> str:
    """Extract user ID from JWT token"""
    if not token:
        return None
    try:
        from jose import jwt
        payload = jwt.decode(token, options={"verify_signature": False})
        return payload.get("sub")
    except Exception:
        return None


def require_auth(token: str = None) -> str:
    user_id = get_current_user_id(token)
    if not user_id:
        raise HTTPException(status_code=401, detail="Not authenticated")
    return user_id


@router.get("/me", response_model=UserResponse)
async def get_me(
    authorization: str = None,
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

    return user


@router.put("/me", response_model=UserResponse)
async def update_me(
    user_data: UserUpdate,
    authorization: str = None,
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