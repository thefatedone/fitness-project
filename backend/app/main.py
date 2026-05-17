from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from app.core.config import settings
from app.core.logging_config import logger
from app.core.redis_client import redis_client


@asynccontextmanager
async def lifespan(app: FastAPI):
    print("=== LIFESPAN STARTING ===", flush=True)

    try:
        await redis_client.connect()
        print("Redis connected", flush=True)
    except Exception as e:
        print(f"Redis connection failed: {e}", flush=True)

    try:
        from app.core.database import engine, Base
        from app.models.user import User
        from app.models.food_log import FoodLog, WeightLog, WaterLog
        from app.models.chat import ChatMessage
        print("=== CREATING TABLES NOW ===", flush=True)
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        print("Database tables verified/created", flush=True)
    except Exception as e:
        print(f"Database initialization failed: {e}", flush=True)

    yield

    try:
        await redis_client.disconnect()
    except Exception:
        pass
    print("Shutting down NutriMind API", flush=True)


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