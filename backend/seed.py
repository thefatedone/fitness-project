import asyncio
import uuid
from datetime import datetime, timedelta
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker
from app.core.config import settings
from app.core.database import Base
from app.core.security import hash_password
from app.models.user import User
from app.models.food_log import FoodLog, WaterLog, WeightLog
from app.models.chat import ChatMessage

engine = create_async_engine(settings.DATABASE_URL, echo=False)
AsyncSessionLocal = async_sessionmaker(engine, expire_on_commit=False)

COMMON_FOODS = [
    {"name": "Chicken Breast", "calories": 165, "protein": 31, "carbs": 0, "fat": 3.6},
    {"name": "Brown Rice (cooked)", "calories": 216, "protein": 5, "carbs": 45, "fat": 1.8},
    {"name": "Broccoli", "calories": 55, "protein": 3.7, "carbs": 11, "fat": 0.6},
    {"name": "Eggs (large)", "calories": 78, "protein": 6, "carbs": 0.6, "fat": 5},
    {"name": "Greek Yogurt", "calories": 100, "protein": 17, "carbs": 6, "fat": 0.7},
    {"name": "Oatmeal (cooked)", "calories": 166, "protein": 6, "carbs": 28, "fat": 3.6},
    {"name": "Banana", "calories": 105, "protein": 1.3, "carbs": 27, "fat": 0.4},
    {"name": "Almonds", "calories": 164, "protein": 6, "carbs": 6, "fat": 14},
    {"name": "Salmon (cooked)", "calories": 208, "protein": 20, "carbs": 0, "fat": 13},
    {"name": "Sweet Potato", "calories": 103, "protein": 2.3, "carbs": 24, "fat": 0.1},
    {"name": "Avocado", "calories": 160, "protein": 2, "carbs": 9, "fat": 15},
    {"name": "Whole Milk", "calories": 149, "protein": 8, "carbs": 12, "fat": 8},
    {"name": "Cheddar Cheese", "calories": 113, "protein": 7, "carbs": 0.4, "fat": 9},
    {"name": "Peanut Butter", "calories": 188, "protein": 8, "carbs": 6, "fat": 16},
    {"name": "White Rice (cooked)", "calories": 206, "protein": 4.3, "carbs": 45, "fat": 0.4},
    {"name": "Pasta (cooked)", "calories": 220, "protein": 8, "carbs": 43, "fat": 1.3},
    {"name": "Tuna (canned)", "calories": 109, "protein": 25, "carbs": 0, "fat": 0.5},
    {"name": "Apple", "calories": 95, "protein": 0.5, "carbs": 25, "fat": 0.3},
    {"name": "Orange", "calories": 62, "protein": 1.2, "carbs": 15, "fat": 0.2},
    {"name": "Blueberries", "calories": 84, "protein": 1.1, "carbs": 21, "fat": 0.5},
    {"name": "Spinach", "calories": 23, "protein": 2.9, "carbs": 3.6, "fat": 0.4},
    {"name": "Lentils (cooked)", "calories": 230, "protein": 18, "carbs": 40, "fat": 0.8},
    {"name": "Black Beans", "calories": 227, "protein": 15, "carbs": 41, "fat": 0.9},
    {"name": "Tofu (firm)", "calories": 144, "protein": 17, "carbs": 3, "fat": 9},
    {"name": "Turkey Breast", "calories": 135, "protein": 30, "carbs": 0, "fat": 1},
    {"name": "Cottage Cheese", "calories": 206, "protein": 25, "carbs": 8, "fat": 9},
    {"name": "Quinoa (cooked)", "calories": 222, "protein": 8, "carbs": 39, "fat": 3.5},
    {"name": "Beef (ground 80/20)", "calories": 287, "protein": 19, "carbs": 0, "fat": 23},
    {"name": "Shrimp (cooked)", "calories": 84, "protein": 18, "carbs": 0, "fat": 0.9},
    {"name": "Bread (whole wheat)", "calories": 69, "protein": 3.6, "carbs": 12, "fat": 1.1},
]

async def seed():
    async with AsyncSessionLocal() as db:
        # Create admin user
        admin = User(
            id=str(uuid.uuid4()),
            email="admin@nutrimind.app",
            password_hash=hash_password("Admin123!"),
            name="Admin",
            role="ADMIN",
            is_active=True,
            onboarding_step=4,
            height=175,
            current_weight=75,
            target_weight=70,
            activity_level="moderate",
            primary_goal="maintain",
            sex="male",
            date_of_birth=datetime(1990, 1, 1),
            bmr=1750,
            tdee=2100,
            daily_cal_target=2100,
            protein_target=158,
            carbs_target=210,
            fat_target=70,
        )
        db.add(admin)

        # Create demo user
        demo = User(
            id=str(uuid.uuid4()),
            email="demo@nutrimind.app",
            password_hash=hash_password("Demo123!"),
            name="Alex Demo",
            role="USER",
            is_active=True,
            onboarding_step=4,
            height=178,
            current_weight=82,
            target_weight=75,
            activity_level="moderate",
            primary_goal="lose_weight",
            sex="male",
            date_of_birth=datetime(1995, 6, 15),
            weight_loss_pace=0.5,
            bmr=1850,
            tdee=2350,
            daily_cal_target=1800,
            protein_target=135,
            carbs_target=180,
            fat_target=60,
        )
        db.add(demo)
        await db.flush()

        # Add 7 days of food logs for demo user
        meals = [
            ("breakfast", "Oatmeal (cooked)", 166, 6, 28, 3.6, 1, "serving"),
            ("breakfast", "Banana", 105, 1.3, 27, 0.4, 1, "piece"),
            ("lunch", "Chicken Breast", 330, 62, 0, 7.2, 200, "g"),
            ("lunch", "Brown Rice (cooked)", 216, 5, 45, 1.8, 1, "cup"),
            ("lunch", "Broccoli", 55, 3.7, 11, 0.6, 1, "cup"),
            ("dinner", "Salmon (cooked)", 208, 20, 0, 13, 150, "g"),
            ("dinner", "Sweet Potato", 103, 2.3, 24, 0.1, 1, "medium"),
            ("snack", "Greek Yogurt", 100, 17, 6, 0.7, 1, "cup"),
            ("snack", "Almonds", 164, 6, 6, 14, 28, "g"),
        ]

        for days_ago in range(7):
            log_date = datetime.utcnow() - timedelta(days=days_ago)
            for meal_type, name, cal, prot, carb, fat, qty, unit in meals:
                log = FoodLog(
                    id=str(uuid.uuid4()),
                    user_id=demo.id,
                    date=log_date,
                    meal_type=meal_type,
                    food_name=name,
                    calories=cal,
                    protein=prot,
                    carbs=carb,
                    fat=fat,
                    quantity=qty,
                    unit=unit,
                )
                db.add(log)

            # Water logs
            water = WaterLog(
                id=str(uuid.uuid4()),
                user_id=demo.id,
                amount=2000,
                date=log_date,
            )
            db.add(water)

            # Weight logs
            weight = WeightLog(
                id=str(uuid.uuid4()),
                user_id=demo.id,
                weight=82 - (days_ago * 0.1),
                date=log_date,
            )
            db.add(weight)

        await db.commit()
        print("✅ Seed complete!")
        print("👤 Admin: admin@nutrimind.app / Admin123!")
        print("👤 Demo:  demo@nutrimind.app / Demo123!")
        print(f"🍎 30 common foods reference created")
        print(f"📊 7 days of food logs created for demo user")

if __name__ == "__main__":
    asyncio.run(seed())