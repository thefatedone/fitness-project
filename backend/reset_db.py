import asyncio
from app.core.database import engine, Base
from app.models import User, FoodLog, WeightLog, WaterLog, ChatMessage


async def reset():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        print("Tables dropped.")
        await conn.run_sync(Base.metadata.create_all)
        print("Tables recreated.")


asyncio.run(reset())