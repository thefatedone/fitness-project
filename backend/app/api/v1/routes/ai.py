from fastapi import APIRouter, HTTPException, Depends, Header
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
import json
import logging
from app.core.database import get_db
from app.core.redis_client import redis_client
from app.core.security import get_current_user_id
from app.models.user import User
from app.models.chat import ChatMessage

logger = logging.getLogger(__name__)

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


@router.post("/chat")
async def chat(
    request: ChatRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """Send a message to the AI assistant and get a streaming response"""
    conversation_id = request.conversation_id or f"user_{user_id}"

    # Get user info for personalization
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()

    user_context = ""
    if user:
        user_context = f"User: {user.full_name}. "
        if user.primary_goal:
            user_context += f"Goal: {user.primary_goal}. "
        if user.dietary_preferences:
            user_context += f"Dietary prefs: {user.dietary_preferences}. "
        if user.food_allergies:
            user_context += f"Allergies: {user.food_allergies}. "

    system_prompt = f"""You are NutriBot, a helpful nutrition and fitness AI assistant. {user_context}
Keep responses concise and helpful. Focus on nutrition, fitness, and wellness topics."""

    async def stream_response():
        ai_text = ""
        try:
            from app.core.config import settings
            import anthropic
            client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)

            with client.messages.stream(
                model="claude-sonnet-4-20250514",
                max_tokens=1024,
                system=system_prompt,
                messages=[{"role": "user", "content": request.message}]
            ) as stream:
                for event in stream:
                    if hasattr(event, 'type') and event.type == "content_block_delta":
                        delta = getattr(event, 'delta', None)
                        if delta and hasattr(delta, 'text'):
                            ai_text += delta.text
                            yield f"data: {json.dumps({'text': delta.text})}\n\n"

            # Store messages in DB after streaming completes
            try:
                user_msg = ChatMessage(
                    user_id=user_id,
                    role="user",
                    content=request.message,
                    conversation_id=conversation_id
                )
                ai_msg = ChatMessage(
                    user_id=user_id,
                    role="assistant",
                    content=ai_text,
                    conversation_id=conversation_id
                )
                db.add(user_msg)
                db.add(ai_msg)
                await db.commit()
            except Exception as e:
                logger.error(f"Failed to save chat messages: {e}")
                await db.rollback()

            yield "data: [DONE]\n\n"

        except Exception as e:
            logger.error(f"AI chat error: {e}")
            yield f"data: {json.dumps({'text': 'I am having trouble connecting to my AI brain right now. Please try again.'})}\n\n"
            yield "data: [DONE]\n\n"

    return StreamingResponse(stream_response(), media_type="text/event-stream")


@router.get("/history", response_model=List[dict])
async def get_all_chat_history(
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    user_id_from_auth = user_id  # already the user_id from auth dependency
    result = await db.execute(
        select(ChatMessage)
        .where(ChatMessage.user_id == user_id_from_auth)
        .order_by(ChatMessage.created_at.asc())
    )
    messages = result.scalars().all()
    return [{"role": m.role, "content": m.content, "created_at": m.created_at.isoformat()} for m in messages]


@router.delete("/history")
async def delete_all_chat_history(
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """Delete all chat messages for the authenticated user"""
    await db.execute(
        delete(ChatMessage).where(ChatMessage.user_id == user_id)
    )
    await db.commit()
    return {"message": "Chat history deleted"}


@router.get("/history/{conversation_id}")
async def get_chat_history(
    conversation_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """Get chat history for a conversation"""
    result = await db.execute(
        select(ChatMessage)
        .where(
            ChatMessage.user_id == user_id,
            ChatMessage.conversation_id == conversation_id
        )
        .order_by(ChatMessage.created_at.asc())
    )
    messages = result.scalars().all()

    return [{"role": m.role, "content": m.content, "created_at": m.created_at.isoformat()} for m in messages]
