from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.database import get_db
from app.core.security import verify_password, get_password_hash, create_access_token
from app.schemas.auth import UserCreate, UserLogin, Token, UserResponse
from app.models.user import User

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=UserResponse)
async def register(user_data: UserCreate, db: AsyncSession = Depends(get_db)):
    if not user_data.email and not user_data.phone:
        raise HTTPException(status_code=400, detail="Email or phone required")

    existing = await db.execute(
        select(User).where(
            (User.email == user_data.email) if user_data.email else (User.phone == user_data.phone)
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="User already registered")

    hashed_pw = get_password_hash(user_data.password)
    new_user = User(
        email=user_data.email,
        phone=user_data.phone,
        password_hash=hashed_pw,
        name=user_data.name,
    )
    db.add(new_user)
    await db.commit()
    await db.refresh(new_user)
    return new_user


@router.post("/login", response_model=Token)
async def login(user_data: UserLogin, db: AsyncSession = Depends(get_db)):
    if not user_data.email and not user_data.phone:
        raise HTTPException(status_code=400, detail="Email or phone required")

    user = await db.execute(
        select(User).where(
            (User.email == user_data.email) if user_data.email else (User.phone == user_data.phone)
        )
    )
    user = user.scalar_one_or_none()

    if not user or not verify_password(user_data.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    access_token = create_access_token(data={"sub": user.id, "role": user.role})
    return {"access_token": access_token, "token_type": "bearer"}