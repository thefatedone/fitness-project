import smtplib
import asyncio
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from app.core.config import settings
from app.core.email_templates import (
    get_contact_confirmation_html,
    get_password_reset_html,
    get_verification_email_html,
)


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
    await asyncio.to_thread(_send)
    return True


async def send_password_reset_email(email: str, code: str) -> bool:
    """Send the 6-digit password-reset code to [email] via SMTP.

    Structure mirrors `send_contact_confirmation_email` exactly:
      * `MIMEMultipart("alternative")` so the message has both a
        plain-text fallback (for accessibility / over-strict clients)
        and a styled HTML body.
      * From / To / Subject populated from the same `settings` block.
      * The blocking `smtplib.SMTP` call wrapped in a nested `_send`
        closure that's run via `asyncio.to_thread` — keeps the FastAPI
        event loop responsive while the SMTP handshake happens.

    The 15-minute expiry is mentioned in the HTML body (the
    server-side `expires_at` is the source of truth — this text is
    purely a UX hint for the user).
    """
    html_content = get_password_reset_html(code)

    msg = MIMEMultipart("alternative")
    msg["Subject"] = "Код для сброса пароля — NutriMind"
    msg["From"] = f"{settings.SMTP_FROM_NAME} <{settings.SMTP_FROM_EMAIL}>"
    msg["To"] = email

    text_part = MIMEText(
        f"Код для сброса пароля NutriMind: {code}\n\n"
        f"Код действителен 15 минут. "
        f"Если ты не запрашивал сброс — проигнорируй это письмо.\n\n"
        f"Команда NutriMind",
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

    await asyncio.to_thread(_send)
    return True


async def send_verification_email(email: str, code: str) -> bool:
    """Send the 6-digit email-verification code to [email] via SMTP.

    Mirrors `send_password_reset_email` exactly — `MIMEMultipart`
    alt/text+HTML, `asyncio.to_thread` for the blocking SMTP call,
    same settings wiring. The body and subject are the only things
    that change; the structural code is identical so a future
    transactional-email addition can copy either function as a
    template without re-thinking the plumbing.

    This is a *soft reminder* flow — the user is already logged in
    when they hit `POST /auth/send-verification-email`, and the
    backend never blocks login on unverified status. The email
    exists so the mobile app can show a "verify your email" banner
    and tap the user to verify; the user verifies (or doesn't) at
    their own pace.
    """
    html_content = get_verification_email_html(code)

    msg = MIMEMultipart("alternative")
    msg["Subject"] = "Подтверди свой email — NutriMind"
    msg["From"] = f"{settings.SMTP_FROM_NAME} <{settings.SMTP_FROM_EMAIL}>"
    msg["To"] = email

    text_part = MIMEText(
        f"Код подтверждения email NutriMind: {code}\n\n"
        f"Код действителен 15 минут. "
        f"Если ты не регистрировался — проигнорируй это письмо.\n\n"
        f"Команда NutriMind",
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

    await asyncio.to_thread(_send)
    return True
