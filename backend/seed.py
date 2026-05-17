import asyncio
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker
from app.core.config import settings
from app.core.security import get_password_hash
from app.models.user import User
from app.core.database import Base


async def seed():
    engine = create_async_engine(settings.async_database_url, echo=False)

    # Create tables if they don't exist
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    from app.core.database import AsyncSessionLocal

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
            {
                "email": "test@nutrimind.com",
                "password": "test123",
                "name": "Test User",
                "role": "USER",
            },
        ]

        created_count = 0
        for user_data in demo_users:
            from sqlalchemy import select
            result = await db.execute(
                select(User).where(User.email == user_data["email"])
            )
            existing_user = result.scalar_one_or_none()

            if not existing_user:
                user = User(
                    email=user_data["email"],
                    password_hash=get_password_hash(user_data["password"]),
                    name=user_data["name"],
                    role=user_data["role"],
                )
                db.add(user)
                created_count += 1
                print(f"Created user: {user_data['email']}")
            else:
                print(f"User already exists: {user_data['email']}")

        await db.commit()
        print(f"\nSeed complete! Created {created_count} new users.")
        print("\nDemo accounts:")
        print("  admin@nutrimind.com / admin123 (ADMIN)")
        print("  demo@nutrimind.com / demo123 (USER)")
        print("  test@nutrimind.com / test123 (USER)")


if __name__ == "__main__":
    asyncio.run(seed())