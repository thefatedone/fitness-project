import smtplib
import asyncio
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from app.core.config import settings
from app.core.email_templates import get_contact_confirmation_html


async def send_contact_confirmation_email(email: str, user_name: str) -> bool:
    """Send a confirmation HTML email asynchronously via SMTP."""
    html_content = get_contact_confirmation_html(user_name)

    msg = MIMEMultipart("alternative")
    msg["Subject"] = "We received your message — NutriMind"
    msg["From"] = f"{settings.SMTP_FROM_NAME} <{settings.SMTP_FROM_EMAIL}>"
    msg["To"] = email

    text_part = MIMEText(
        f"Hi {user_name},\n\n"
        f"We've received your message and our team will get back to you within 24 hours.\n\n"
        f"Best,\nThe NutriMind Team",
        "plain"
    )
    html_part = MIMEText(html_content, "html")
    msg.attach(text_part)
    msg.attach(html_part)

    def _send():
        with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT) as server:
            if settings.SMTP_TLS:
                server.starttls()
            if settings.SMTP_USER:
                server.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
            server.sendmail(settings.SMTP_FROM_EMAIL, [email], msg.as_string())

    # Run blocking SMTP in executor to keep it non-blocking
    await asyncio.get_event_loop().run_in_executor(None, _send)
    return True