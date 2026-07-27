from typing import Optional


def get_contact_confirmation_html(user_name: str) -> str:
    """Modern inline-CSS HTML email template matching NutriMind dark + green brand."""
    return f"""
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Message Received — NutriMind</title>
</head>
<body style="margin: 0; padding: 0; background-color: #0a0a0a; font-family: Arial, sans-serif;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background-color: #0a0a0a;">
        <tr>
            <td align="center" style="padding: 40px 20px;">
                <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0"
                       style="max-width: 600px; background-color: #111111; border-radius: 16px; overflow: hidden;">
                    <!-- Logo Header -->
                    <tr>
                        <td style="padding: 32px 40px 24px; background-color: #111111;">
                            <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%">
                                <tr>
                                    <td width="40" style="vertical-align: middle;">
                                        <div style="width: 40px; height: 40px; background-color: #22c55e; border-radius: 10px; text-align: center; line-height: 40px; font-size: 20px; font-weight: bold; color: black;">N</div>
                                    </td>
                                    <td style="padding-left: 12px; vertical-align: middle;">
                                        <span style="font-size: 20px; font-weight: bold; color: white;">NutriMind</span>
                                    </td>
                                </tr>
                            </table>
                        </td>
                    </tr>
                    <!-- Divider -->
                    <tr>
                        <td style="padding: 0 40px;">
                            <div style="height: 1px; background-color: #1a1a1a;"></div>
                        </td>
                    </tr>
                    <!-- Body -->
                    <tr>
                        <td style="padding: 40px 40px 32px; background-color: #111111;">
                            <h1 style="margin: 0 0 16px; font-size: 24px; font-weight: bold; color: white;">
                                We've received your message, {user_name}!
                            </h1>
                            <p style="margin: 0 0 20px; font-size: 16px; line-height: 24px; color: #9ca3af;">
                                Thank you for reaching out. Our management team has received your inquiry and will get back to you within <strong style="color: white;">24 hours</strong>.
                            </p>
                            <p style="margin: 0 0 24px; font-size: 16px; line-height: 24px; color: #9ca3af;">
                                In the meantime, feel free to connect with us on Telegram:<br/>
                                <a href="https://t.me/nutrim1ndbot" style="color: #22c55e; text-decoration: none;">@nutrim1ndbot</a>
                            </p>
                            <div style="background-color: #0d0d0d; border-left: 4px solid #22c55e; border-radius: 8px; padding: 16px 20px;">
                                <p style="margin: 0; font-size: 14px; line-height: 22px; color: #9ca3af;">
                                    🌱 <strong style="color: white;">NutriMind</strong> — Your AI-powered nutrition companion.<br/>
                                    Eat smart. Live better.
                                </p>
                            </div>
                        </td>
                    </tr>
                    <!-- Footer -->
                    <tr>
                        <td style="padding: 24px 40px; background-color: #0d0d0d; text-align: center;">
                            <p style="margin: 0 0 8px; font-size: 12px; color: #6b7280;">
                                This is an automated message — please do not reply to this email.
                            </p>
                            <p style="margin: 0; font-size: 12px; color: #6b7280;">
                                © 2026 NutriMind. All rights reserved.
                            </p>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>
"""


def get_password_reset_html(code: str) -> str:
    """Modern inline-CSS HTML email template for the password-reset
    6-digit code. Mirrors the same dark + green NutriMind brand as
    `get_contact_confirmation_html` so the two feel like a family of
    transactional emails.

    The code itself is rendered inside a dark "monospace card" with
    generous letter-spacing and a 32 px font so it's easy to read on
    mobile and hard to typo when transcribing it into the app. The
    expiry line ("15 minutes") is right below it in the muted
    surface colour so it's the second thing the eye lands on.
    """
    return f"""
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Password reset — NutriMind</title>
</head>
<body style="margin: 0; padding: 0; background-color: #0a0a0a; font-family: Arial, sans-serif;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background-color: #0a0a0a;">
        <tr>
            <td align="center" style="padding: 40px 20px;">
                <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0"
                       style="max-width: 600px; background-color: #111111; border-radius: 16px; overflow: hidden;">
                    <!-- Logo Header -->
                    <tr>
                        <td style="padding: 32px 40px 24px; background-color: #111111;">
                            <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%">
                                <tr>
                                    <td width="40" style="vertical-align: middle;">
                                        <div style="width: 40px; height: 40px; background-color: #22c55e; border-radius: 10px; text-align: center; line-height: 40px; font-size: 20px; font-weight: bold; color: black;">N</div>
                                    </td>
                                    <td style="padding-left: 12px; vertical-align: middle;">
                                        <span style="font-size: 20px; font-weight: bold; color: white;">NutriMind</span>
                                    </td>
                                </tr>
                            </table>
                        </td>
                    </tr>
                    <!-- Divider -->
                    <tr>
                        <td style="padding: 0 40px;">
                            <div style="height: 1px; background-color: #1a1a1a;"></div>
                        </td>
                    </tr>
                    <!-- Body -->
                    <tr>
                        <td style="padding: 40px 40px 32px; background-color: #111111;">
                            <h1 style="margin: 0 0 16px; font-size: 24px; font-weight: bold; color: white;">
                                Сброс пароля
                            </h1>
                            <p style="margin: 0 0 24px; font-size: 16px; line-height: 24px; color: #9ca3af;">
                                Мы получили запрос на сброс пароля для твоего аккаунта.
                                Введи этот код в приложении, чтобы задать новый пароль.
                            </p>

                            <!-- Code block — large, monospaced, letter-spaced
                                 for easy transcription on a phone keyboard. -->
                            <div style="background-color: #0d0d0d; border-radius: 12px; padding: 24px 16px; text-align: center; margin: 0 0 16px;">
                                <div style="font-family: 'Courier New', Courier, monospace; font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #22c55e;">
                                    {code}
                                </div>
                            </div>

                            <p style="margin: 0 0 24px; font-size: 14px; line-height: 22px; color: #6b7280; text-align: center;">
                                Код действителен 15 минут. Если ты не запрашивал сброс — просто проигнорируй это письмо.
                            </p>

                            <div style="background-color: #0d0d0d; border-left: 4px solid #22c55e; border-radius: 8px; padding: 16px 20px;">
                                <p style="margin: 0; font-size: 14px; line-height: 22px; color: #9ca3af;">
                                    🔒 <strong style="color: white;">Совет</strong>: никому не сообщай этот код.
                                    Команда NutriMind никогда не попросит твой пароль или код.
                                </p>
                            </div>
                        </td>
                    </tr>
                    <!-- Footer -->
                    <tr>
                        <td style="padding: 24px 40px; background-color: #0d0d0d; text-align: center;">
                            <p style="margin: 0 0 8px; font-size: 12px; color: #6b7280;">
                                This is an automated message — please do not reply to this email.
                            </p>
                            <p style="margin: 0; font-size: 12px; color: #6b7280;">
                                © 2026 NutriMind. All rights reserved.
                            </p>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>
"""


def get_verification_email_html(code: str) -> str:
    """Modern inline-CSS HTML email template for the email-verification
    6-digit code — sent to a freshly-registered or unverified user.

    Mirrors the same dark + green NutriMind brand family as
    `get_password_reset_html` (so the two transactional emails feel
    related) but with copy appropriate to "welcome, verify your
    email" rather than "reset your password":
      * Header: "Добро пожаловать в NutriMind!" for the very first
        email flow a user ever sees — this is also a soft reminder
        flow on subsequent sends, so the body still works.
      * Body copy explicitly invites the user to enter the code in
        the app (the email is a *passive* trigger — the user does
        the work in the app).
      * Code block: same large monospaced 32 px / 8 px letter-spacing
        centered table as the reset template.
      * 15-minute expiry is mentioned in the muted gray line below
        the code.
    """
    return f"""
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Verify your email — NutriMind</title>
</head>
<body style="margin: 0; padding: 0; background-color: #0a0a0a; font-family: Arial, sans-serif;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background-color: #0a0a0a;">
        <tr>
            <td align="center" style="padding: 40px 20px;">
                <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0"
                       style="max-width: 600px; background-color: #111111; border-radius: 16px; overflow: hidden;">
                    <!-- Logo Header -->
                    <tr>
                        <td style="padding: 32px 40px 24px; background-color: #111111;">
                            <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%">
                                <tr>
                                    <td width="40" style="vertical-align: middle;">
                                        <div style="width: 40px; height: 40px; background-color: #22c55e; border-radius: 10px; text-align: center; line-height: 40px; font-size: 20px; font-weight: bold; color: black;">N</div>
                                    </td>
                                    <td style="padding-left: 12px; vertical-align: middle;">
                                        <span style="font-size: 20px; font-weight: bold; color: white;">NutriMind</span>
                                    </td>
                                </tr>
                            </table>
                        </td>
                    </tr>
                    <!-- Divider -->
                    <tr>
                        <td style="padding: 0 40px;">
                            <div style="height: 1px; background-color: #1a1a1a;"></div>
                        </td>
                    </tr>
                    <!-- Body -->
                    <tr>
                        <td style="padding: 40px 40px 32px; background-color: #111111;">
                            <h1 style="margin: 0 0 16px; font-size: 24px; font-weight: bold; color: white;">
                                Добро пожаловать в NutriMind!
                            </h1>
                            <p style="margin: 0 0 24px; font-size: 16px; line-height: 24px; color: #9ca3af;">
                                Подтверди свой email, введя этот код в приложении:
                            </p>

                            <!-- Code block — same OTP-style monospace treatment
                                 as the password-reset template so the two
                                 transactional emails feel like siblings. -->
                            <div style="background-color: #0d0d0d; border-radius: 12px; padding: 24px 16px; text-align: center; margin: 0 0 16px;">
                                <div style="font-family: 'Courier New', Courier, monospace; font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #22c55e;">
                                    {code}
                                </div>
                            </div>

                            <p style="margin: 0 0 24px; font-size: 14px; line-height: 22px; color: #6b7280; text-align: center;">
                                Код действителен 15 минут. Если ты не регистрировался — проигнорируй это письмо.
                            </p>

                            <div style="background-color: #0d0d0d; border-left: 4px solid #22c55e; border-radius: 8px; padding: 16px 20px;">
                                <p style="margin: 0; font-size: 14px; line-height: 22px; color: #9ca3af;">
                                    🌱 <strong style="color: white;">Подсказка</strong>: подтверждение email необязательно — приложение работает и без него. Это просто способ подтвердить, что email действительно твой.
                                </p>
                            </div>
                        </td>
                    </tr>
                    <!-- Footer -->
                    <tr>
                        <td style="padding: 24px 40px; background-color: #0d0d0d; text-align: center;">
                            <p style="margin: 0 0 8px; font-size: 12px; color: #6b7280;">
                                This is an automated message — please do not reply to this email.
                            </p>
                            <p style="margin: 0; font-size: 12px; color: #6b7280;">
                                © 2026 NutriMind. All rights reserved.
                            </p>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>
"""
