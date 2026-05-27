from fastapi import APIRouter, HTTPException, BackgroundTasks
from app.schemas.contact import ContactFormIn
from app.core.telegram_bot import contact_form_forward
from app.core.email_sender import send_contact_confirmation_email

router = APIRouter(prefix="/contact", tags=["contact"])


@router.post("/submit")
async def submit_contact_form(
    data: ContactFormIn,
    background_tasks: BackgroundTasks,
):
    """
    Accept contact form submission.
    - Forwards inquiry to owner via Telegram (async, non-blocking)
    - Sends confirmation email to user (background task)
    - Always returns success to the frontend
    """
    # Notify owner on Telegram (fire and forget)
    try:
        await contact_form_forward(
            first_name=data.first_name,
            last_name=data.last_name,
            email=data.email,
            phone=data.phone or "Not provided",
            purpose=data.purpose,
            message=data.message or "No message"
        )
    except Exception:
        pass  # Telegram is optional, don't fail the request

    # Send confirmation email in background
    full_name = f"{data.first_name} {data.last_name}"
    background_tasks.add_task(
        send_contact_confirmation_email,
        data.email,
        full_name
    )

    return {"status": "ok", "message": "Message sent successfully"}