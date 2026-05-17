from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel
from typing import Optional
from datetime import datetime
import json
from jose import jwt
from app.core.database import get_db
from app.core.redis_client import redis_client
from app.models.user import User
from app.models.chat import ChatMessage

router = APIRouter(prefix="/ai", tags=["ai"])


class Message(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    message: str
    conversation_id: Optional[str] = None


class ChatResponse(BaseModel):
    response: str
    conversation_id: str


def get_user_id_from_token(authorization: str = None) -> Optional[str]:
    try:
        if not authorization or not authorization.startswith("Bearer "):
            return None
        token = authorization.replace("Bearer ", "")
        payload = jwt.decode(token, options={"verify_signature": False})
        return payload.get("sub")
    except Exception:
        return None


@router.post("/chat", response_model=ChatResponse)
async def chat(
    request: ChatRequest,
    authorization: str = None,
    db: AsyncSession = Depends(get_db)
):
    """Send a message to the AI assistant and get a response"""
    user_id = get_user_id_from_token(authorization)
    if not user_id:
        raise HTTPException(status_code=401, detail="Not authenticated")

    # Generate or use conversation ID
    conversation_id = request.conversation_id or f"user_{user_id}"

    # Get user info for personalization
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()

    # Build context from user profile
    user_context = ""
    if user:
        user_context = f"User: {user.name}. "
        if user.primary_goal:
            user_context += f"Goal: {user.primary_goal}. "
        if user.dietary_prefs:
            user_context += f"Dietary prefs: {user.dietary_prefs}. "
        if user.allergies:
            user_context += f"Allergies: {user.allergies}. "

    # Store user message in Redis for context
    try:
        await redis_client.publish(
            f"chat:{conversation_id}",
            json.dumps({"role": "user", "content": request.message, "timestamp": datetime.utcnow().isoformat()})
        )
    except Exception:
        pass  # Redis not critical for basic chat

    # Build prompt for AI
    system_prompt = f"""You are NutriBot, a helpful nutrition and fitness AI assistant. {user_context}
Keep responses concise and helpful. Focus on nutrition, fitness, and wellness topics."""

    # Call Anthropic API
    try:
        from app.core.config import settings
        import anthropic
        client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)

        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=1024,
            system=system_prompt,
            messages=[{"role": "user", "content": request.message}]
        )

        ai_response = response.content[0].text
    except Exception as e:
        ai_response = f"I'm having trouble connecting to my AI brain right now. Please try again. Error: {str(e)}"

    # Store AI response in Redis
    try:
        await redis_client.publish(
            f"chat:{conversation_id}",
            json.dumps({"role": "assistant", "content": ai_response, "timestamp": datetime.utcnow().isoformat()})
        )
    except Exception:
        pass

    # Store in database
    try:
        user_msg = ChatMessage(user_id=user_id, role="user", content=request.message)
        ai_msg = ChatMessage(user_id=user_id, role="assistant", content=ai_response)
        db.add(user_msg)
        db.add(ai_msg)
        await db.commit()
    except Exception:
        pass  # DB storage is not critical

    return ChatResponse(response=ai_response, conversation_id=conversation_id)


@router.get("/history/{conversation_id}")
async def get_chat_history(
    conversation_id: str,
    authorization: str = None,
    db: AsyncSession = Depends(get_db)
):
    """Get chat history for a conversation"""
    user_id = get_user_id_from_token(authorization)
    if not user_id:
        raise HTTPException(status_code=401, detail="Not authenticated")

    result = await db.execute(
        select(ChatMessage)
        .where(ChatMessage.user_id == user_id)
        .order_by(ChatMessage.created_at.asc())
    )
    messages = result.scalars().all()

    return [{"role": m.role, "content": m.content, "created_at": m.created_at.isoformat()} for m in messages]