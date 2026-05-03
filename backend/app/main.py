from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.v1.routes import auth, users, tracker, ai

app = FastAPI(
    title="NutriMind API",
    version="1.0.0",
    docs_url="/api/docs"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/api/v1/auth", tags=["auth"])
app.include_router(users.router, prefix="/api/v1/users", tags=["users"])
app.include_router(tracker.router, prefix="/api/v1/tracker", tags=["tracker"])
app.include_router(ai.router, prefix="/api/v1/ai", tags=["ai"])


@app.get("/health")
async def health():
    return {"status": "ok", "version": "1.0.0"}