import random
import re
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, EmailStr
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError

from app.core.database import get_db
from app.core.security import (
    verify_password,
    get_password_hash,
    create_access_token,
    validate_password_strength,
    get_current_user,
)
from app.core.email_sender import (
    send_password_reset_email,
    send_verification_email,
)
from app.models.user import User
from app.models.password_reset import PasswordResetCode
from app.schemas.auth import UserCreate, UserLogin, Token, UserResponse
from app.schemas.user import VerifyEmailRequest

router = APIRouter(prefix="/auth", tags=["auth"])

EMAIL_REGEX = re.compile(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")

# How long a freshly-issued reset code stays redeemable. Matches the
# 15-minute copy in the email body and the `expires_at` value we stamp
# on new `PasswordResetCode` rows below.
RESET_CODE_TTL = timedelta(minutes=15)

# Same 15-minute TTL for the email-verification single-code column.
# Unlike password reset, there's no separate history table — a new
# code overwrites the old one in `users.email_verification_code_hash`.
VERIFICATION_CODE_TTL = timedelta(minutes=15)

# Generic success copy returned by every forgot-password call, whether
# or not the email actually maps to a registered user. Email-
# enumeration prevention — an attacker probing the endpoint cannot
# distinguish "no such user" from "code sent".
_FORGOT_OK_MESSAGE = (
    "Если аккаунт с таким email существует, мы отправили код."
)

# Single error copy returned by every code-validation failure
# (unknown email, no code, expired code, used code, hash mismatch).
# Same response for every case — same enumeration-prevention
# principle as above, applied to the verification step.
_BAD_CODE_MESSAGE = "Неверный или истёкший код."

# Copy used by the email-verification flow when the user already
# verified their email. Returned early from both /send-verification-email
# and /verify-email so the UI can show a friendly "all set" message
# after a redundant call.
_ALREADY_VERIFIED_MESSAGE = "Email уже подтверждён."

# Copy used by /send-verification-email when the user has no email
# (phone-only account). Don't fall back to a generic 400 — the
# distinction matters because the user can resolve it by adding an
# email via the profile screen, not by retrying.
_NO_EMAIL_MESSAGE = "У аккаунта не указан email."

# Copy used by /send-verification-email on success.
_VERIFICATION_SENT_MESSAGE = "Код подтверждения отправлен на email."

# Copy used by /verify-email on success.
_VERIFICATION_OK_MESSAGE = "Email подтверждён!"


# ============================================================================
# Body schemas for the password-reset and email-verification flows
# ============================================================================

class ForgotPasswordRequest(BaseModel):
    """Body for `POST /auth/forgot-password`. Only `email` is needed —
    the endpoint deliberately doesn't accept a username or phone
    because the password-reset flow is anchored to the email channel
    (the code goes to the user's inbox)."""
    email: EmailStr


class VerifyResetCodeRequest(BaseModel):
    """Body for `POST /auth/verify-reset-code`. The client sends
    this BEFORE showing the "set new password" screen so it can show
    a clear "code accepted" / "code rejected" state without burning
    the code on a typo."""
    email: EmailStr
    code: str


class ResetPasswordRequest(BaseModel):
    """Body for `POST /auth/reset-password`. `code` is RE-VERIFIED on
    this endpoint rather than trusted from the verify step, so a
    client that bypassed the verify call can't redeem a code without
    proving the user just typed it again."""
    email: EmailStr
    code: str
    new_password: str


# `VerifyEmailRequest` lives in `app.schemas.user` so the schema
# module owns the User-flavored DTOs; we re-import it above so the
# auth route reads as a single self-contained file.


# ============================================================================
# Helpers
# ============================================================================

def _now_naive_utc() -> datetime:
    """Naive UTC `datetime` for SQLAlchemy comparisons against
    `expires_at`. We compare the code's expiry to a freshly-computed
    `now()` rather than relying on DB clock skew."""
    return datetime.now(timezone.utc).replace(tzinfo=None)


async def _lookup_valid_code(
    db: AsyncSession, user_id: str, raw_code: str
) -> PasswordResetCode | None:
    """Find the user's most recent non-used, non-expired code and
    return it if the supplied [raw_code] matches the stored hash.

    Returns `None` for any of:
      * no row at all for this user
      * all rows are used or expired
      * a row exists but the bcrypt verify fails (i.e. wrong code)

    Importantly does *not* flip `used` to True — that's deferred to
    `reset-password`, so a user can re-enter the code without burning
    it on a typo.
    """
    now = _now_naive_utc()
    result = await db.execute(
        select(PasswordResetCode)
        .where(
            PasswordResetCode.user_id == user_id,
            PasswordResetCode.used == False,
            PasswordResetCode.expires_at > now,
        )
        .order_by(PasswordResetCode.created_at.desc())
        .limit(1)
    )
    candidate = result.scalar_one_or_none()
    if candidate is None:
        return None
    if not verify_password(raw_code, candidate.code_hash):
        return None
    return candidate


def _hash_reset_code(raw_code: str) -> str:
    """Hash a 6-digit reset code with the same bcrypt path as passwords.

    Lives here (rather than on the model) so the model module can
    stay free of `app.core.security` imports — that would create a
    cycle (security imports `models.user`, which imports
    `models.__init__`, which used to import `password_reset`).
    """
    return get_password_hash(raw_code)


async def _issue_verification_code(
    current_user: User, db: AsyncSession
) -> None:
    """Generate a 6-digit code, hash it, stamp it on the user row,
    commit, and try to email it. The bcrypt hash + 15-minute expiry
    mirror the password-reset flow's invariants — same `random.randint`
    range, same TTL.

    Called from BOTH the dedicated `/send-verification-email` route
    AND the tail of `/register`, so the two sending paths can't
    drift. Best-effort email send: a mail-server failure is logged
    with `debugPrint` and swallowed — the user can re-request from
    the in-app banner and the code is already in the DB.
    """
    raw_code = str(random.randint(100000, 999999))
    now = _now_naive_utc()

    current_user.email_verification_code_hash = _hash_reset_code(raw_code)
    current_user.email_verification_expires_at = now + VERIFICATION_CODE_TTL
    await db.commit()

    try:
        await send_verification_email(current_user.email, raw_code)
    except Exception as e:
        # Don't let a mail-transport hiccup block the caller — the
        # code is already persisted, so a re-request from the
        # in-app banner will re-email the same code (or a fresh one).
        # We log so the failure is visible in server logs without
        # surfacing to the client.
        print(f"[email-verification] send failed for user "
              f"{current_user.id}: {e!r}")


# ============================================================================
# Endpoints
# ============================================================================

@router.post("/register", response_model=Token)
async def register(user_data: UserCreate, db: AsyncSession = Depends(get_db)):
    if not user_data.email and not user_data.phone:
        raise HTTPException(status_code=400, detail="Email or phone required")

    # Validate email format if provided
    if user_data.email and not EMAIL_REGEX.match(user_data.email):
        raise HTTPException(status_code=400, detail="Invalid email format")

    # Password strength — same three rules as the Pydantic validator
    # on `PasswordChangeRequest.new_password` (see core/security.py).
    # Sharing the helper keeps the rule set in one place so a future
    # tightening (e.g. "must contain a special character") only needs
    # one edit instead of two.
    pwd_err = validate_password_strength(user_data.password)
    if pwd_err:
        raise HTTPException(status_code=400, detail=pwd_err)

    hashed_pw = get_password_hash(user_data.password)
    new_user = User(
        email=user_data.email,
        phone=user_data.phone,
        password_hash=hashed_pw,
        full_name=user_data.full_name,
    )
    db.add(new_user)

    try:
        await db.commit()
        await db.refresh(new_user)
    except IntegrityError:
        await db.rollback()
        raise HTTPException(status_code=400, detail="User with this email or phone already exists")

    # Auto-issue a verification code + email for newly-registered
    # users with an email. This is a *soft* reminder — we never block
    # login on unverified status, so the user can ignore the email
    # entirely. Mirrors the same defensive pattern as /forgot-password:
    # the email send is best-effort and lives in the same try-block
    # boundary so a mail-server hiccup never affects the registration
    # response.
    if new_user.email is not None:
        try:
            await _issue_verification_code(new_user, db)
        except Exception:
            # The code is already in the DB at this point (if it got
            # that far); surfacing the error to the client would force
            # a useless re-registration. We swallow and the user can
            # re-send from the in-app banner.
            pass

    access_token = create_access_token(data={"sub": new_user.id, "role": new_user.role})
    return {"access_token": access_token, "token_type": "bearer"}


@router.post("/login", response_model=Token)
async def login(user_data: UserLogin, db: AsyncSession = Depends(get_db)):
    if not user_data.email and not user_data.phone:
        raise HTTPException(status_code=400, detail="Email or phone required")

    user = await db.execute(
        select(User).where(
            (User.email == user_data.email) if user_data.email else (User.phone == user_data.phone)
        )
    )
    user = user.scalar_one_or_none()

    if not user or not verify_password(user_data.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    access_token = create_access_token(data={"sub": user.id, "role": user.role})
    return {"access_token": access_token, "token_type": "bearer"}


# ============================================================================
# Password-reset flow — three endpoints, 6-digit email code
# ============================================================================

@router.post("/forgot-password")
async def forgot_password(
    body: ForgotPasswordRequest,
    db: AsyncSession = Depends(get_db)
):
    """Generate a 6-digit reset code, store its hash, email it.

    Always returns 200 with the same generic success message —
    whether the email maps to a real user or not. Email-enumeration
    prevention: an attacker probing the endpoint cannot distinguish
    "no such account" from "code sent" from the response shape.
    """
    user_result = await db.execute(
        select(User).where(User.email == body.email)
    )
    user = user_result.scalar_one_or_none()

    if user is not None:
        # (1) Invalidate every previously-issued unused code for this
        # user so only the latest one is ever valid. Doing this
        # unconditionally (whether or not the user re-requests a code
        # immediately) keeps the "most recent code wins" invariant
        # simple to reason about — no parallel branches in the route.
        now = _now_naive_utc()
        await db.execute(
            update(PasswordResetCode)
            .where(
                PasswordResetCode.user_id == user.id,
                PasswordResetCode.used == False,
            )
            .values(used=True)
        )

        # (2) Generate a new 6-digit numeric code, hash it, and store it.
        # The numeric range `100000..=999999` guarantees exactly six
        # digits with no leading-zero ambiguity for the user.
        raw_code = str(random.randint(100000, 999999))
        new_code = PasswordResetCode(
            user_id=user.id,
            code_hash=_hash_reset_code(raw_code),
            expires_at=now + RESET_CODE_TTL,
            used=False,
        )
        db.add(new_code)
        await db.commit()

        # (3) Send the email. If the SMTP send fails (mailhog down,
        # credentials wrong, etc.) we swallow the error and still
        # return the generic success — the next forgot-password call
        # will generate a fresh code + try again. We never want to
        # surface the underlying mail-server error to the client;
        # that would defeat the enumeration-prevention story.
        try:
            await send_password_reset_email(user.email, raw_code)
        except Exception:
            # Intentionally broad — the user can't do anything about a
            # broken mail transport, and a follow-up call to this
            # endpoint will retry the send with a new code.
            pass

    # (4) Same response shape whether the email is known or not.
    return {"message": _FORGOT_OK_MESSAGE}


@router.post("/verify-reset-code")
async def verify_reset_code(
    body: VerifyResetCodeRequest,
    db: AsyncSession = Depends(get_db)
):
    """Tell the client whether the supplied code is currently
    redeemable. Does *not* mark the code used — that's deferred to
    `reset-password` so a typo on the entry screen doesn't burn the
    user's only attempt.

    Returns the same generic error for every failure mode (no
    user, no code, expired, used, wrong code) so an attacker
    probing the endpoint can't distinguish between them.
    """
    user_result = await db.execute(
        select(User).where(User.email == body.email)
    )
    user = user_result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=400, detail=_BAD_CODE_MESSAGE)

    code_row = await _lookup_valid_code(db, user.id, body.code)
    if code_row is None:
        raise HTTPException(status_code=400, detail=_BAD_CODE_MESSAGE)

    return {"valid": True}


@router.post("/reset-password")
async def reset_password(
    body: ResetPasswordRequest,
    db: AsyncSession = Depends(get_db)
):
    """Re-verify the code (independent of the verify endpoint — the
    client can't skip the verify step), validate the new password's
    strength, then atomically flip the code to used AND swap the
    user's password hash.

    The 400 / "strength error" detail surfaces in the body's
    `detail` field; the mobile client's `ApiException.fromDioError`
    pulls it out verbatim and surfaces in a SnackBar.
    """
    # (1) Strength-validate the new password first — the error copy
    # is the same one registration + the change-password flow use,
    # so a single source of truth on the wire. A user who sends
    # "abcdef" should see "Password must contain at least one digit"
    # rather than the more generic code-rejected message.
    pwd_err = validate_password_strength(body.new_password)
    if pwd_err:
        raise HTTPException(status_code=400, detail=pwd_err)

    # (2) Re-verify (don't trust the verify step). The lookup is
    # identical to `verify-reset-code` so the same generic 400 is
    # returned for every failure mode.
    user_result = await db.execute(
        select(User).where(User.email == body.email)
    )
    user = user_result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=400, detail=_BAD_CODE_MESSAGE)

    code_row = await _lookup_valid_code(db, user.id, body.code)
    if code_row is None:
        raise HTTPException(status_code=400, detail=_BAD_CODE_MESSAGE)

    # (3) Atomic swap: stamp the code used and update the password
    # hash in a single commit. If the commit fails, neither side
    # persists — the user can retry with the same code (until it
    # expires) without the system entering a half-applied state.
    code_row.used = True
    user.password_hash = get_password_hash(body.new_password)
    await db.commit()

    return {"message": "Пароль успешно изменён."}


# ============================================================================
# Email-verification flow — two endpoints, 6-digit email code
# ============================================================================
#
# This is a *soft reminder* feature, NOT an access gate. Login works
# regardless of `is_email_verified`; the only consumer of the flag
# is the home screen's "verify your email" banner, which the user can
# dismiss forever if they want. The code lives on the user row itself
# (no separate history table) — a new code overwrites the old one.

@router.post("/send-verification-email")
async def send_verification_email_route(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Generate / re-fetch a fresh 6-digit verification code and email it.

    Three short-circuits:
      * already verified → 200 with the "already verified" copy so
        the UI can show a friendly message.
      * account has no email (phone-only) → 400 with a Russian hint
        that explains the user can resolve this by adding an email
        via the profile screen.
      * otherwise → hash + stamp + email, returning the standard
        "code sent" copy.
    """
    if current_user.is_email_verified:
        return {"message": _ALREADY_VERIFIED_MESSAGE}

    if not current_user.email:
        raise HTTPException(status_code=400, detail=_NO_EMAIL_MESSAGE)

    # _issue_verification_code writes the hash + expiry, commits, and
    # best-effort emails the code. Mail-transport failures are swallowed
    # inside the helper so a mailhog outage never blocks the call.
    await _issue_verification_code(current_user, db)

    return {"message": _VERIFICATION_SENT_MESSAGE}


@router.post("/verify-email")
async def verify_email(
    body: VerifyEmailRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Check the supplied 6-digit code against the active code on the
    user row. On success: clear the active code (no reason to keep a
    spent code lying around) and stamp `is_email_verified=True`.

    Already-verified is a short-circuit so the UI can retry the call
    idempotently. The 400 path is a single generic message — same
    enumeration-prevention principle used by the password-reset
    flow: a user probing the endpoint can't distinguish between
    "no code", "expired", "already verified", and "wrong code".
    """
    if current_user.is_email_verified:
        return {"message": _ALREADY_VERIFIED_MESSAGE}

    # Three preconditions before the bcrypt compare:
    #   (a) a code has been issued at all,
    #   (b) it hasn't expired,
    #   (c) the user-typed code matches the stored hash.
    if (current_user.email_verification_code_hash is None
            or current_user.email_verification_expires_at is None
            or current_user.email_verification_expires_at <= _now_naive_utc()):
        raise HTTPException(status_code=400, detail=_BAD_CODE_MESSAGE)

    if not verify_password(body.code, current_user.email_verification_code_hash):
        raise HTTPException(status_code=400, detail=_BAD_CODE_MESSAGE)

    # All three checks passed — flip the verified flag and wipe the
    # active code so the row doesn't carry around a now-spent hash.
    # Atomic in a single commit; if it fails, the user retries with
    # the same code (well, the same code *if* it hasn't expired yet —
    # once it's wiped, a new code needs to be requested).
    current_user.is_email_verified = True
    current_user.email_verification_code_hash = None
    current_user.email_verification_expires_at = None
    await db.commit()

    return {"message": _VERIFICATION_OK_MESSAGE}
