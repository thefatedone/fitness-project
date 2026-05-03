from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.database import get_db
from app.core.security import (
    hash_password, verify_password,
    create_access_token, create_refresh_token, decode_token
)
from app.models.user import User
from app.schemas.auth import RegisterRequest, LoginRequest, TokenResponse, RefreshRequest
from app.services.nutrition_service import calculate_bmr, calculate_tdee, calculate_targets
import uuid

router = APIRouter()


@router.post("/register", response_model=TokenResponse)
async def register(data: RegisterRequest, db: AsyncSession = Depends(get_db)):
    if not data.email and not data.phone:
        raise HTTPException(status_code=400, detail="Email or phone required")

    # Check if user exists
    if data.email:
        result = await db.execute(select(User).where(User.email == data.email))
        if result.scalar_one_or_none():
            raise HTTPException(status_code=400, detail="Email already registered")

    user = User(
        id=str(uuid.uuid4()),
        email=data.email,
        phone=data.phone,
        password_hash=hash_password(data.password),
        name=data.name,
        onboarding_step=1,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)

    token_data = {"sub": user.id}
    return TokenResponse(
        access_token=create_access_token(token_data),
        refresh_token=create_refresh_token(token_data),
    )


@router.post("/login", response_model=TokenResponse)
async def login(data: LoginRequest, db: AsyncSession = Depends(get_db)):
    if data.email:
        result = await db.execute(select(User).where(User.email == data.email))
    elif data.phone:
        result = await db.execute(select(User).where(User.phone == data.phone))
    else:
        raise HTTPException(status_code=400, detail="Email or phone required")

    user = result.scalar_one_or_none()
    if not user or not verify_password(data.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    if not user.is_active:
        raise HTTPException(status_code=403, detail="Account suspended")

    token_data = {"sub": user.id}
    return TokenResponse(
        access_token=create_access_token(token_data),
        refresh_token=create_refresh_token(token_data),
    )


@router.post("/refresh", response_model=TokenResponse)
async def refresh(data: RefreshRequest, db: AsyncSession = Depends(get_db)):
    payload = decode_token(data.refresh_token)
    if not payload or payload.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    user_id = payload.get("sub")
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    token_data = {"sub": user.id}
    return TokenResponse(
        access_token=create_access_token(token_data),
        refresh_token=create_refresh_token(token_data),
    )