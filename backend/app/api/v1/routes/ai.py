from fastapi import APIRouter, HTTPException, Depends, Header
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete, func, distinct
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime, timedelta, timezone
import json
import logging
from app.core.database import get_db
from app.core.redis_client import redis_client
from app.core.security import get_current_user_id
from app.models.user import User
from app.models.food_log import FoodLog, WeightLog
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


# ---------------------------------------------------------------------------
# Context building
# ---------------------------------------------------------------------------

def _parse_age(dob) -> Optional[int]:
    if not dob:
        return None
    today = datetime.utcnow().date()
    return today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))


def _parse_csv_tags(raw) -> List[str]:
    """Dietary preferences / allergies are stored as CSV strings on the User
    row; turn them into a clean list for the prompt."""
    if not raw:
        return []
    if isinstance(raw, list):
        return [str(x).strip() for x in raw if str(x).strip()]
    return [s.strip() for s in str(raw).split(",") if s.strip()]


def _build_user_profile_block(user: User) -> str:
    age = _parse_age(user.date_of_birth)
    preferences = _parse_csv_tags(user.dietary_preferences)
    allergies = _parse_csv_tags(user.food_allergies)

    lines = [
        "USER PROFILE",
        f"- Name: {user.full_name}",
        f"- Age: {age if age is not None else 'not provided'}",
        f"- Sex: {user.sex or 'not provided'}",
        f"- Height: {user.height} cm" if user.height else "- Height: not provided",
        f"- Current weight: {user.current_weight} kg" if user.current_weight else "- Current weight: not provided",
        f"- Target weight: {user.target_weight} kg" if user.target_weight else "- Target weight: not provided",
        f"- Activity level: {user.activity_level or 'not provided'}",
        f"- Primary goal: {user.primary_goal or 'not provided'}",
        f"- Weight-loss pace: {user.weight_loss_pace} kg/week" if user.weight_loss_pace else "- Weight-loss pace: not provided",
        f"- Dietary preferences: {', '.join(preferences) if preferences else 'none'}",
        f"- Allergies / intolerances: {', '.join(allergies) if allergies else 'none'}",
        "",
        "CALCULATED NUTRITION TARGETS",
        f"- BMR: {user.bmr} kcal/day" if user.bmr else "- BMR: not calculated (height/weight missing)",
        f"- TDEE: {user.tdee} kcal/day" if user.tdee else "- TDEE: not calculated",
        f"- Daily calorie target: {user.daily_cal_target} kcal" if user.daily_cal_target else "- Daily calorie target: not set",
        f"- Protein target: {user.protein_target} g" if user.protein_target is not None else "- Protein target: not set",
        f"- Carbs target: {user.carbs_target} g" if user.carbs_target is not None else "- Carbs target: not set",
        f"- Fat target: {user.fat_target} g" if user.fat_target is not None else "- Fat target: not set",
    ]
    return "\n".join(lines)


async def _build_recent_intake_block(user: User, db: AsyncSession) -> str:
    """Average intake over the last 7 days, with % of target."""
    days = 7
    since = datetime.utcnow() - timedelta(days=days)

    # Sum totals, then we'll divide by number of distinct days the user logged on.
    stmt = (
        select(
            func.count(distinct(FoodLog.date)),
            func.coalesce(func.sum(FoodLog.calories), 0),
            func.coalesce(func.sum(FoodLog.protein), 0),
            func.coalesce(func.sum(FoodLog.carbs), 0),
            func.coalesce(func.sum(FoodLog.fat), 0),
        )
        .where(FoodLog.user_id == user.id, FoodLog.date >= since)
    )
    row = (await db.execute(stmt)).one()
    n_logged_days, total_cal, total_protein, total_carbs, total_fat = row

    if n_logged_days == 0:
        return "RECENT INTAKE (last 7 days)\n- No food entries logged yet."

    # Average per logged day (a fair basis even if the user only logged 3 days).
    n_days = max(1, n_logged_days)
    avg_cal = float(total_cal) / n_days
    avg_protein = float(total_protein) / n_days
    avg_carbs = float(total_carbs) / n_days
    avg_fat = float(total_fat) / n_days

    def pct(value, target):
        if not target:
            return "n/a"
        return f"{(value / float(target) * 100):.0f}%"

    return (
        "RECENT INTAKE (last 7 days, averaged across logged days)\n"
        f"- Calories: {avg_cal:.0f} kcal ({pct(avg_cal, user.daily_cal_target)} of target)\n"
        f"- Protein:  {avg_protein:.1f} g ({pct(avg_protein, user.protein_target)} of target)\n"
        f"- Carbs:    {avg_carbs:.1f} g ({pct(avg_carbs, user.carbs_target)} of target)\n"
        f"- Fat:      {avg_fat:.1f} g ({pct(avg_fat, user.fat_target)} of target)"
    )


async def _build_weight_trend_block(user: User, db: AsyncSession) -> str:
    """Latest weight + 30-day delta."""
    days = 30
    since = datetime.utcnow() - timedelta(days=days)

    stmt = (
        select(WeightLog)
        .where(WeightLog.user_id == user.id, WeightLog.date >= since)
        .order_by(WeightLog.date.desc())
    )
    logs = (await db.execute(stmt)).scalars().all()
    if not logs:
        return "WEIGHT TREND (last 30 days)\n- No weight entries yet."

    latest = logs[0]
    # Find oldest in window for delta
    oldest_in_window = logs[-1]
    delta = latest.weight - oldest_in_window.weight
    days_span = max(1, (latest.date - oldest_in_window.date).days)
    rate_per_week = (delta / days_span) * 7 if days_span else 0

    direction = "↓ lost" if delta < 0 else ("↑ gained" if delta > 0 else "→ unchanged")
    return (
        "WEIGHT TREND (last 30 days)\n"
        f"- Latest: {latest.weight} kg on {latest.date.date().isoformat()}\n"
        f"- 30-day change: {delta:+.1f} kg ({direction})\n"
        f"- Pace: {rate_per_week:+.2f} kg/week"
    )


async def _build_system_prompt(user: User, db: AsyncSession) -> str:
    profile = _build_user_profile_block(user)
    intake = await _build_recent_intake_block(user, db)
    weight = await _build_weight_trend_block(user, db)

    return f"""You are NutriBot, a friendly and evidence-based nutrition and fitness AI assistant for the NutriMind app. You have access to the user's complete profile and recent tracking data below — use it on EVERY response to give personalised advice grounded in their actual numbers and habits.

{profile}

{intake}

{weight}

BEHAVIOUR
- Reference the user's real measurements, targets, and trends instead of generic advice (no "eat 2000 kcal a day" if their target is different).
- Tie recommendations to their primary goal and current pace.
- Respect dietary preferences and flag anything that conflicts with their allergies.
- When asked about progress, compare their recent intake averages to their targets and comment on adherence.
- Be encouraging but honest. If their weight trend is moving the wrong way for their goal, say so kindly.
- Keep responses under ~200 words unless the user asks for detail.
- If a question is outside nutrition, fitness, or wellness, gently redirect.
"""


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

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

    system_prompt = await _build_system_prompt(user, db) if user else (
        "You are NutriBot, a friendly nutrition and fitness AI assistant."
    )

    async def stream_response():
        ai_text = ""
        try:
            from app.core.config import settings
            import anthropic
            client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)

            logger.info(
                "AI chat request: model=%s user=%s msg_len=%d prompt_len=%d",
                settings.ANTHROPIC_MODEL, user_id, len(request.message), len(system_prompt),
            )

            with client.messages.stream(
                model=settings.ANTHROPIC_MODEL,
                max_tokens=2048,
                system=system_prompt,
                messages=[{"role": "user", "content": request.message}]
            ) as stream:
                for event in stream:
                    # content_block_delta fires for every delta in a streaming
                    # message, including non-text blocks (thinking, tool_use,
                    # input_json). Only forward + accumulate when `text` is
                    # actually present and not None.
                    if getattr(event, 'type', None) == "content_block_delta":
                        delta = getattr(event, 'delta', None)
                        chunk = getattr(delta, 'text', None) if delta is not None else None
                        if chunk:
                            ai_text += chunk
                            yield f"data: {json.dumps({'text': chunk})}\n\n"

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
            # Surface the actual upstream error in server logs so we can debug
            # model-not-found / auth / rate-limit issues, while still telling
            # the user something friendly on the wire.
            logger.exception("AI chat failed (model=%s): %s", settings.ANTHROPIC_MODEL, e)
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