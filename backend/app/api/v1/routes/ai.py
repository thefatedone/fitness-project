from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from app.core.database import get_db
from app.models.user import User
from app.models.chat import ChatMessage
from app.models.food_log import FoodLog, WaterLog
from app.api.v1.routes.users import get_current_user
from app.core.config import settings
from pydantic import BaseModel
from datetime import datetime, date
import anthropic
import json
import uuid

router = APIRouter()


class ChatRequest(BaseModel):
    message: str


async def get_today_summary(user_id: str, db: AsyncSession) -> dict:
    today = date.today()
    start = datetime.combine(today, datetime.min.time())
    end = datetime.combine(today, datetime.max.time())

    result = await db.execute(
        select(FoodLog).where(
            FoodLog.user_id == user_id,
            FoodLog.date >= start,
            FoodLog.date <= end
        )
    )
    logs = result.scalars().all()

    water_result = await db.execute(
        select(func.sum(WaterLog.amount)).where(
            WaterLog.user_id == user_id,
            WaterLog.date >= start,
            WaterLog.date <= end
        )
    )
    water_ml = water_result.scalar() or 0

    totals = {"calories": 0, "protein": 0, "carbs": 0, "fat": 0}
    for log in logs:
        totals["calories"] += log.calories
        totals["protein"] += log.protein
        totals["carbs"] += log.carbs
        totals["fat"] += log.fat

    return {**totals, "water_ml": water_ml}


@router.post("/chat")
async def chat(
    data: ChatRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    today = await get_today_summary(current_user.id, db)
    remaining = (current_user.daily_cal_target or 2000) - today["calories"]

    # Build system prompt with user context
    system_prompt = f"""You are NutriMind AI, an expert nutrition coach
and registered dietitian assistant. Be encouraging, specific, practical.

User Profile:
- Name: {current_user.name}
- Daily calorie target: {current_user.daily_cal_target or "not set"} kcal
- Goal: {current_user.primary_goal or "not set"}
- Activity level: {current_user.activity_level or "not set"}
- Dietary preferences: {current_user.dietary_prefs or "none"}
- Allergies: {current_user.allergies or "none"}

Today's Progress:
- Calories consumed: {round(today["calories"])} kcal
- Remaining: {round(remaining)} kcal
- Protein: {round(today["protein"])}g
- Carbs: {round(today["carbs"])}g
- Fat: {round(today["fat"])}g
- Water: {today["water_ml"]}ml

When users describe food, always estimate calories and macros.
Never recommend extreme diets. Suggest consulting a doctor for
medical concerns. Keep responses concise and friendly."""

    # Get last 10 messages for context
    history_result = await db.execute(
        select(ChatMessage)
        .where(ChatMessage.user_id == current_user.id)
        .order_by(ChatMessage.created_at.desc())
        .limit(10)
    )
    history = list(reversed(history_result.scalars().all()))

    messages = [
        {"role": msg.role, "content": msg.content}
        for msg in history
    ]
    messages.append({"role": "user", "content": data.message})

    # Save user message
    user_msg = ChatMessage(
        id=str(uuid.uuid4()),
        user_id=current_user.id,
        role="user",
        content=data.message,
    )
    db.add(user_msg)
    await db.commit()

    # Stream response from Claude
    client = anthropic.AsyncAnthropic(api_key=settings.ANTHROPIC_API_KEY)
    full_response = []

    async def generate():
        async with client.messages.stream(
            model="claude-sonnet-4-20250514",
            max_tokens=1024,
            system=system_prompt,
            messages=messages,
        ) as stream:
            async for text in stream.text_stream:
                full_response.append(text)
                yield f"data: {json.dumps({'text': text})}\n\n"

        # Save assistant response after streaming
        assistant_content = "".join(full_response)
        assistant_msg = ChatMessage(
            id=str(uuid.uuid4()),
            user_id=current_user.id,
            role="assistant",
            content=assistant_content,
        )
        async with db as session:
            session.add(assistant_msg)
            await session.commit()

        yield "data: [DONE]\n\n"

    return StreamingResponse(
        generate(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
        }
    )


@router.get("/history")
async def get_history(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(ChatMessage)
        .where(ChatMessage.user_id == current_user.id)
        .order_by(ChatMessage.created_at.asc())
        .limit(50)
    )
    messages = result.scalars().all()
    return [
        {
            "id": msg.id,
            "role": msg.role,
            "content": msg.content,
            "created_at": msg.created_at.isoformat(),
        }
        for msg in messages
    ]


@router.delete("/history")
async def clear_history(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(ChatMessage).where(ChatMessage.user_id == current_user.id)
    )
    for msg in result.scalars().all():
        await db.delete(msg)
    await db.commit()
    return {"message": "Chat history cleared"}