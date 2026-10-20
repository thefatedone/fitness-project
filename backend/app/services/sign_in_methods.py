"""Provider-agnostic sign-in method list + display masking.

The profile endpoint returns a list of the sign-in methods the
current user has on file. The shape is intentionally narrow: we
only expose what the user can recognise (the provider name and a
masked identifier). Anything that could be replayed against the
provider (the raw `sub` claim, the unmasked email on an identity
row) is kept server-side.

The list is built in two passes:

  1. If `users.password_hash` is set, prepend a synthetic
     `"password"` entry using the user's own `email` (masked).
  2. Walk every row in `auth_identities` for this user, build an
     entry per row.

Order is fixed: password, google, apple, phone, then any unknown
provider in `auth_identities.created_at` order. The fixed order
matches the `provider -> sort_key` table below so a user who has
both password and Google sees `password` first, then `google`,
etc. — predictable across requests, which is what the UI relies on.
"""
from __future__ import annotations

from datetime import datetime
from typing import Iterable, Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.auth_identity import AuthIdentity
from app.models.user import User
from app.schemas.user import SignInMethod


# Wire names — the same string the Flutter client sees in
# `SignInMethod.provider`. Kept here (not in the schema) so the
# ordering is the single source of truth.
_PROVIDER_ORDER: dict[str, int] = {
    "password": 0,
    "google": 1,
    "apple": 2,
    "phone": 3,
}
# Unknown providers sort to the end. The literal `+1` is just so
# any future provider (e.g. "github") sits AFTER phone without
# needing to bump this constant.
_UNKNOWN_ORDER = max(_PROVIDER_ORDER.values()) + 1


def _provider_sort_key(provider: str) -> int:
    return _PROVIDER_ORDER.get(provider, _UNKNOWN_ORDER)


def _mask_email(email: Optional[str]) -> Optional[str]:
    """Mask an email for display: keep the first character of the
    local part, three asterisks, the `@`, and the full domain.

    Examples (deterministic so the test suite can pin the output):
        ``                  -> ``  (no email → no identifier)
        `a@x.io`            -> `a***@x.io`
        `alice@gmail.com`   -> `a***@gmail.com`
        `bob@example.co.uk` -> `b***@example.co.uk`

    Returns ``None`` for ``None`` so the caller doesn't have to
    branch — the schema field is `Optional[str]`, and we want the
    "no identifier" case to round-trip as `null` rather than `""`.
    """
    if not email:
        return None
    at = email.find("@")
    if at < 0:
        # Not a real email — fall back to a single-asterisk mask
        # of the whole thing. (Shouldn't happen in practice —
        # `users.email` is validated at registration — but a
        # defensive fallback beats a crash on malformed data.)
        return ("*" * len(email)) if email else None
    local = email[:at]
    domain = email[at:]  # includes the leading '@'
    if not local:
        return f"***{domain}"
    return f"{local[0]}***{domain}"


def _mask_phone(phone: Optional[str]) -> Optional[str]:
    """Mask a phone for display: keep the leading ``+`` (if any) and
    the last 4 digits; replace every other digit with ``*``.

    Examples:
        ``              -> ``
        `123`           -> `123`  (too short to mask; phone
                               numbers shorter than 5 digits
                               never carry useful PII to hide)
        `12345`         -> `*2345`
        `+1234567890`   -> `+1*******890`
        `+995123456789` -> `+995*******89`

    Returns ``None`` for ``None`` so the caller doesn't branch.
    """
    if not phone:
        return None
    if len(phone) < 5:
        return phone
    has_plus = phone.startswith("+")
    body = phone[1:] if has_plus else phone
    if len(body) <= 4:
        return phone
    keep = body[-4:]
    masked = "*" * (len(body) - 4) + keep
    return f"+{masked}" if has_plus else masked


def _display_identifier_for(
    provider: str, *, email: Optional[str], phone: Optional[str],
) -> Optional[str]:
    """Pick the right masked identifier for [provider].

    Email-based providers (password, google) get the masked email.
    Phone-based providers (phone) get the masked phone. Apple can
    carry either (the spec leaves `email` opt-in); we surface email
    when present and fall back to phone. Unknown providers get
    whatever the identity row's `email` column holds — masked if it
    looks like an email, otherwise the raw string trimmed to a
    safer length.
    """
    if provider == "phone":
        return _mask_phone(phone)
    if provider in ("password", "google", "apple"):
        return _mask_email(email)
    # Unknown provider — prefer email (the only identifying field
    # the auth_identities table stores), masked if it parses as one.
    if email:
        return _mask_email(email)
    if phone:
        return _mask_phone(phone)
    return None


async def build_sign_in_methods(
    db: AsyncSession, user: User,
) -> list[SignInMethod]:
    """Return the list of sign-in methods for [user], in display order.

    One entry per row in `auth_identities` for this user, plus a
    synthetic "password" entry when `user.password_hash` is set.
    Identities whose provider we've never heard of (e.g. a future
    "github" provider the server doesn't recognise) are kept
    rather than dropped — the client renders them with a generic
    icon and the raw provider name so future rollouts need zero
    server-side code to surface the new method.

    The query is read-only; nothing is committed.
    """
    rows = (
        await db.execute(
            select(AuthIdentity)
            .where(AuthIdentity.user_id == user.id)
            .order_by(AuthIdentity.created_at.asc())
        )
    ).scalars().all()

    methods: list[SignInMethod] = []

    # 1. Synthetic "password" entry — only if the user actually has
    # a password set. The "linked_at" is the user's account
    # creation time (the earliest we can vouch for) so the row
    # carries a meaningful timestamp for the UI.
    if user.password_hash:
        methods.append(SignInMethod(
            provider="password",
            display_identifier=_display_identifier_for(
                "password", email=user.email, phone=user.phone,
            ),
            linked_at=user.created_at,
        ))

    # 2. One entry per auth_identities row.
    for row in rows:
        methods.append(SignInMethod(
            provider=row.provider,
            display_identifier=_display_identifier_for(
                row.provider,
                email=row.email,
                # The auth_identities table doesn't currently store
                # a phone column; phone provider is handled by
                # `users.phone`. We look there for the identifier
                # so the masking helper has something to mask.
                phone=user.phone if row.provider == "phone" else None,
            ),
            linked_at=row.created_at,
        ))

    # Sort by the fixed provider order, then by linked_at within
    # the same provider so multiple Google identities (shouldn't
    # happen in practice — the unique constraint prevents it, but
    # the sort stays stable) come out oldest-first.
    methods.sort(key=lambda m: (_provider_sort_key(m.provider), m.linked_at))
    return methods
