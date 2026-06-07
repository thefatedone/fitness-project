import os
import httpx
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes

BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", "")
OWNER_CHAT_ID = os.getenv("TELEGRAM_OWNER_CHAT_ID", "")

WELCOME_MESSAGE = """👋 Welcome to NutriMind!

Thank you for reaching out. Our team has received your message and we will get back to you as soon as possible.

For urgent inquiries, please email us at support@nutrimind.app

Best regards,
The NutriMind Team 🌱"""


async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text(
        text=WELCOME_MESSAGE,
        parse_mode="Markdown"
    )


async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.message.from_user
    first_name = user.first_name
    last_name = user.last_name or ""

    if OWNER_CHAT_ID:
        forward_text = f"""📩 New Bot Message
👤 {first_name} {last_name}
👤 Username: @{user.username or 'no username'}
🆔 Telegram ID: {user.id}

💬 Message:
{update.message.text or '(no text)'}"""

        try:
            await context.bot.send_message(
                chat_id=int(OWNER_CHAT_ID),
                text=forward_text
            )
        except Exception as e:
            print(f"Failed to forward message: {e}")

    await update.message.reply_text(
        text=WELCOME_MESSAGE,
        parse_mode="Markdown"
    )


async def contact_form_forward(
    first_name: str,
    last_name: str,
    email: str,
    phone: str,
    purpose: str,
    message: str
) -> dict:
    """Called from the backend contact endpoint to notify the owner via Telegram."""
    if not OWNER_CHAT_ID:
        return {"success": False, "error": "OWNER_CHAT_ID not set"}

    notification_text = f"""📩 Contact Form Submission
👤 {first_name} {last_name}
📧 {email}
📱 {phone}
🏷️ Purpose: {purpose}
💬 Message: {message}"""

    try:
        async with httpx.AsyncClient() as client:
            await client.post(
                f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage",
                json={"chat_id": int(OWNER_CHAT_ID), "text": notification_text}
            )
        return {"success": True}
    except Exception as e:
        return {"success": False, "error": str(e)}


def run_bot():
    """Run the Telegram bot polling (separate process)."""
    app = Application.builder().token(BOT_TOKEN).build()
    app.add_handler(CommandHandler("start", start_command))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
    app.run_polling()


if __name__ == "__main__":
    run_bot()