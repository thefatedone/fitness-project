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