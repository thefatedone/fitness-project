"""Provider-agnostic user lookup / creation by IdP identity.

Single entry point used by every social / phone login flow — Google
now, Apple and 6-digit-SMS-phone in later steps. The contract is
deliberately narrow: caller hands us a `(provider, provider_user_id)`
pair (the IdP's stable identifier for the user) plus optional email
+ display name + email-verified flag, and gets back the
`[User, bool]` tuple — the user that should be logged in, and
whether that user was *just* created.

The three rules:

  1. If an `AuthIdentity` for `(provider, provider_user_id)` already
     exists, return that user. (Re-login of an existing social user.)
  2. Otherwise, if `email` is set AND `email_verified` is True AND a
     user with that email already exists, attach a new identity
     row to the existing user. (Account linking — the IdP
     vouched for the email, so we trust it's the same person.)
  3. Otherwise, create a new `User` (no password — `password_hash`
     stays NULL, which the model already supports) plus a new
     `AuthIdentity` row.

Rule 2 is the security boundary. NEVER link by an unverified email
— an attacker who controls `attacker@example.com` could mint a
JWT with that email and `email_verified: true` from a hostile IdP
configuration; but no real IdP lets a *user* set that bit, so the
`email_verified` flag IS the trust signal. We refuse to link when
it's False.

The function is intentionally async-ORM rather than a pure helper:
a future Apple / phone step will need exactly the same lookup-or-
create shape, and the email-link case needs the same transaction so
the identity row and the existing user are observed atomically. All
mutations live in one `db.flush()`+`db.commit()` cycle.

Email normalisation: the IdP's email is lowercased and stripped
before lookup so `Alice@Example.com` and `alice@example.com` land
on the same row. The user table's `email` column is implicitly
case-sensitive at the DB layer (no `lower()` index), so callers
who pre-populate `users.email` should match the same convention.
The existing `register` route does NOT lowercase — it relies on
the form's `email` field being already-lowercase on the client
side. The mismatch is acceptable here because social linking is
about the IdP's email matching an existing row; if a user
registered with `Mixed@Case.com` and the IdP returns
`mixed@case.com`, the link won't fire and a duplicate account
will be created. The fix lives in the registration route (out of
scope for this PR).
"""
from __future__ import annotations

from typing import Optional, Tuple

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.auth_identity import AuthIdentity
from app.models.user import User


async def get_or_create_user_from_identity(
    db: AsyncSession,
    provider: str,
    provider_user_id: str,
    *,
    email: Optional[str] = None,
    email_verified: bool = False,
    display_name: Optional[str] = None,
) -> Tuple[User, bool]:
    """Look up or create the [User] matching the given IdP identity.

    Returns a `(user, created)` tuple:
      * `created=True` when this call minted a new `User` and a
        fresh `AuthIdentity` for it.
      * `created=False` when the user already existed (either via a
        pre-existing identity row, or by being linked to an
        existing email-verified user — the `User` is reused in
        both cases; only the `AuthIdentity` row may be new).

    The `provider` and `provider_user_id` arguments are required
    and must uniquely identify the user at the IdP. `email`,
    `email_verified`, and `display_name` are all optional; missing
    values are treated as "the IdP didn't tell us" rather than
    "the IdP told us they're empty". The same is true for
    `display_name` — a missing name means we synthesise one from
    the email local-part (or fall back to "User" if there's no
    email either) so the row is never `NOT NULL`-violating.
    """
    if not provider or not provider_user_id:
        # The route never hits this — the Pydantic body / IdP
        # library guarantees both fields — but asserting here
        # keeps the service function honest if a future caller
        # (e.g. an Apple route) wires it up wrong.
        raise ValueError("provider and provider_user_id are required")

    # 1. Identity already exists → that user.
    existing_identity = await db.execute(
        select(AuthIdentity).where(
            AuthIdentity.provider == provider,
            AuthIdentity.provider_user_id == provider_user_id,
        )
    )
    identity = existing_identity.scalar_one_or_none()
    if identity is not None:
        user = await db.get(User, identity.user_id)
        if user is None:
            # Dangling FK — the user was hard-deleted but the
            # identity wasn't, or the test suite created a
            # half-row. Treat as "not found" and fall through to
            # the create path so the next call heals it.
            identity = None
        else:
            return user, False

    # 2. Verified email matches an existing user → link.
    linked_user: Optional[User] = None
    if email and email_verified:
        normalised = email.strip().lower()
        linked = await db.execute(
            select(User).where(User.email == normalised)
        )
        linked_user = linked.scalar_one_or_none()
        if linked_user is not None:
            db.add(AuthIdentity(
                user_id=linked_user.id,
                provider=provider,
                provider_user_id=provider_user_id,
                email=normalised,
                email_verified=True,
            ))
            try:
                await db.commit()
            except IntegrityError:
                # A concurrent request beat us to it: someone
                # else already linked this `(provider,
                # provider_user_id)`. Roll back and return the
                # existing user instead.
                await db.rollback()
                existing = await db.execute(
                    select(AuthIdentity).where(
                        AuthIdentity.provider == provider,
                        AuthIdentity.provider_user_id == provider_user_id,
                    )
                )
                identity = existing.scalar_one()
                user = await db.get(User, identity.user_id)
                if user is not None:
                    return user, False
            return linked_user, False

    # 3. Create a brand-new user + identity.
    new_user = User(
        email=(email.strip().lower() if email and email_verified else None),
        # phone stays None for social login — phone-login (a
        # later step) is the only path that fills this column.
        phone=None,
        password_hash=None,  # social-only user — no password.
        full_name=_synthesise_display_name(display_name, email),
    )
    db.add(new_user)
    # Flush so `new_user.id` is populated before we INSERT into
    # `auth_identities` (which has a FK to `users.id`).
    await db.flush()

    db.add(AuthIdentity(
        user_id=new_user.id,
        provider=provider,
        provider_user_id=provider_user_id,
        email=(email.strip().lower() if email and email_verified else None),
        email_verified=email_verified,
    ))
    try:
        await db.commit()
    except IntegrityError:
        # Race: another concurrent call already created the
        # identity. Roll back and return that user.
        await db.rollback()
        existing = await db.execute(
            select(AuthIdentity).where(
                AuthIdentity.provider == provider,
                AuthIdentity.provider_user_id == provider_user_id,
            )
        )
        identity = existing.scalar_one()
        user = await db.get(User, identity.user_id)
        if user is None:
            # Truly stuck — FK still dangling. Re-raise so the
            # caller sees a 500 and we get a stack trace to fix
            # the underlying bug.
            raise
        return user, False

    await db.refresh(new_user)
    return new_user, True


def _synthesise_display_name(
    explicit: Optional[str],
    email: Optional[str],
) -> str:
    """Pick a [User.full_name] when the IdP didn't give us one.

    `User.full_name` is `nullable=False`, so we must always return
    a non-empty string. The preference order:
      1. The IdP's own name (when provided).
      2. The email's local-part — `alice@example.com` →
         `Alice` (title-cased because most apps show the name
         that way in the UI).
      3. A literal `"User"` as the last-resort default.
    """
    if explicit and explicit.strip():
        return explicit.strip()
    if email and email.strip():
        local = email.split("@", 1)[0].strip()
        if local:
            return local[:1].upper() + local[1:]
    return "User"
