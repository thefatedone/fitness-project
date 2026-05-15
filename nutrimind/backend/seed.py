import asyncio
from sqlalchemy import select
from app.core.database import AsyncSessionLocal
from app.core.security import get_password_hash
from app.models.user import User


async def seed():
    async with AsyncSessionLocal() as db:
        demo_users = [
            {
                "email": "admin@nutrimind.com",
                "password": "admin123",
                "name": "Admin User",
                "role": "ADMIN",
            },
            {
                "email": "demo@nutrimind.com",
                "password": "demo123",
                "name": "Demo User",
                "role": "USER",
            },
        ]

        for user_data in demo_users:
            result = await db.execute(
                select(User).where(User.email == user_data["email"])
            )
            existing = result.scalar_one_or_none()

            if not existing:
                user = User(
                    email=user_data["email"],
                    password_hash=get_password_hash(user_data["password"]),
                    name=user_data["name"],
                    role=user_data["role"],
                )
                db.add(user)
                print(f"Created {user_data['email']}")
            else:
                print(f"User {user_data['email']} already exists")

        await db.commit()
        print("Seed complete!")


if __name__ == "__main__":
    asyncio.run(seed())