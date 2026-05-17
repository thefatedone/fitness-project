from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from app.core.config import settings
from app.core.logging_config import logger
from app.core.redis_client import redis_client


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting NutriMind API")

    try:
        await redis_client.connect()
        logger.info("Redis connected")
    except Exception as e:
        logger.error(f"Redis connection failed: {e}")

    try:
        from app.core.database import engine, Base
        from app.models.user import User
        from app.models.food_log import FoodLog, WeightLog, WaterLog
        from app.models.chat import ChatMessage
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        logger.info("Database tables verified/created")
    except Exception as e:
        logger.error(f"Database initialization failed: {e}")

    yield

    try:
        await redis_client.disconnect()
    except Exception:
        pass
    logger.info("Shutting down NutriMind API")


app = FastAPI(title="NutriMind API", version="1.0.0", docs_url="/api/docs")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", settings.FRONTEND_URL],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

from app.api.v1.routes import auth, users, tracker, ai
app.include_router(auth.router, prefix="/api/v1")
app.include_router(users.router, prefix="/api/v1")
app.include_router(tracker.router, prefix="/api/v1")
app.include_router(ai.router, prefix="/api/v1")


@app.get("/health")
async def health():
    return {"status": "ok", "version": "1.0.0"}