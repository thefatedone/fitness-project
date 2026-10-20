"""Unit tests for the sign-in-method list builder + masking helpers.

The service function in `app.services.sign_in_methods` is the single
source of truth for "what does the profile endpoint return under
the `sign_in_methods` field". The tests below pin four things:

  * **List construction**: password-only / Google-only / both /
    no-password-social-only all produce the right entries in the
    right order.
  * **Masking**: emails become `a***@gmail.com`-style; phones keep
    the country code and the last 4 digits, mask the rest.
  * **No raw provider ids leak**: the response never includes a
    `sub` claim or any other IdP-side identifier.
  * **Unknown providers pass through**: a row in `auth_identities`
    with a provider name the server doesn't know about (e.g. a
    future "github") still surfaces in the list, so the mobile
    client can render a generic icon + the raw provider string.

Everything is in-process — we use the same SQLite-in-memory
`AsyncSession` pattern as `test_auth_identity.py`.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone

import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

import aiosqlite  # noqa: F401  (registers the SQLite dialect)

from app.core.config import settings  # noqa: F401  (loads env before models)
from app.core.database import Base
from app.models.auth_identity import AuthIdentity
from app.models.user import User
from app.services.sign_in_methods import (
    _display_identifier_for,
    _mask_email,
    _mask_phone,
    build_sign_in_methods,
)


def _sqlite_url() -> str:
    return f"sqlite+aiosqlite:///:memory:"


@pytest_asyncio.fixture
async def db() -> AsyncIterator[AsyncSession]:
    engine = create_async_engine(_sqlite_url(), echo=False)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    SessionLocal = async_sessionmaker(engine, expire_on_commit=False)
    async with SessionLocal() as session:
        yield session
    await engine.dispose()


def _user(
    *,
    email: str | None = None,
    phone: str | None = None,
    password_hash: str | None = "bcrypt-placeholder",
) -> User:
    return User(
        email=email,
        phone=phone,
        password_hash=password_hash,
        full_name="Test User",
        created_at=datetime(2024, 1, 1, tzinfo=timezone.utc),
    )


def _identity(
    user_id: str,
    provider: str,
    *,
    email: str | None = None,
) -> AuthIdentity:
    return AuthIdentity(
        user_id=user_id,
        provider=provider,
        provider_user_id=f"{provider}-sub-{uuid.uuid4().hex[:8]}",
        email=email,
        email_verified=True,
    )


# ---------------------------------------------------------------------------
# Masking helpers — pure functions, no DB needed
# ---------------------------------------------------------------------------

class TestMaskEmail:
    def test_basic_email(self):
        assert _mask_email("alice@gmail.com") == "a***@gmail.com"

    def test_single_char_local_part(self):
        # Even a one-character local part gets one char + ***. The
        # function never returns a fully-revealed email.
        assert _mask_email("a@x.io") == "a***@x.io"

    def test_long_local_part(self):
        # Always three asterisks, regardless of the local-part
        # length. The first character carries the "this is a real
        # address" signal; the rest is hidden.
        assert _mask_email("robert.smith@example.co.uk") == "r***@example.co.uk"

    def test_none_returns_none(self):
        assert _mask_email(None) is None

    def test_empty_returns_none(self):
        assert _mask_email("") is None

    def test_no_at_sign_falls_back_to_mask(self):
        # Malformed input — defensive fallback. We never want to
        # return a half-revealed string for a non-email.
        assert _mask_email("noatsign") == "*" * len("noatsign")


class TestMaskPhone:
    def test_basic_phone(self):
        assert _mask_phone("+1234567890") == "+******7890"

    def test_long_international(self):
        # Always keep the last 4 digits, mask the rest.
        # +995123456789 → + + "********" (8 asterisks) + "6789"
        assert _mask_phone("+995123456789") == "+********6789"

    def test_no_plus(self):
        # No `+` prefix → just mask the middle, keep the last 4.
        assert _mask_phone("1234567890") == "******7890"

    def test_short_returns_unchanged(self):
        # 4 digits and below is too short to usefully mask — the
        # last-4 rule would show the whole thing.
        assert _mask_phone("1234") == "1234"
        assert _mask_phone("123") == "123"

    def test_none_returns_none(self):
        assert _mask_phone(None) is None

    def test_empty_returns_none(self):
        assert _mask_phone("") is None


# ---------------------------------------------------------------------------
# build_sign_in_methods — the meat of the feature
# ---------------------------------------------------------------------------

class TestBuildSignInMethods:
    async def test_password_only_user_has_one_entry(self, db: AsyncSession):
        # The most common case today: a user who signed up with
        # email + password and never linked any IdP.
        user = _user(email="alice@gmail.com")
        db.add(user)
        await db.commit()
        await db.refresh(user)

        methods = await build_sign_in_methods(db, user)

        assert len(methods) == 1
        m = methods[0]
        assert m.provider == "password"
        assert m.display_identifier == "a***@gmail.com"
        # `linked_at` falls back to the user's account creation
        # time when no real "password linked" timestamp exists.
        assert m.linked_at == user.created_at

    async def test_google_only_user_has_one_entry(self, db: AsyncSession):
        # Social-only user — no `password_hash`, no `email`, but
        # one Google identity with a verified email. The list has
        # one entry (Google) and NO synthetic password row.
        user = _user(email=None, phone=None, password_hash=None)
        db.add(user)
        await db.commit()
        await db.refresh(user)
        db.add(_identity(user.id, "google", email="alice@gmail.com"))
        await db.commit()

        methods = await build_sign_in_methods(db, user)

        assert [m.provider for m in methods] == ["google"]
        assert methods[0].display_identifier == "a***@gmail.com"

    async def test_user_with_both_has_password_first_then_google(
        self, db: AsyncSession,
    ):
        # Order matters — the UI relies on the fixed
        # password → google → apple → phone ordering so a user
        # who has both reads as "email" first, "Google" second.
        user = _user(email="alice@gmail.com")
        db.add(user)
        await db.commit()
        await db.refresh(user)
        db.add(_identity(user.id, "google", email="alice@gmail.com"))
        await db.commit()

        methods = await build_sign_in_methods(db, user)

        assert [m.provider for m in methods] == ["password", "google"]
        # Both rows mask the same email — the synthetic password
        # entry uses `users.email`, the Google entry uses
        # `auth_identities.email`. Same masking → same output.
        assert all(m.display_identifier == "a***@gmail.com" for m in methods)

    async def test_apple_with_email_uses_email_for_display(
        self, db: AsyncSession,
    ):
        user = _user(email=None, password_hash=None)
        db.add(user)
        await db.commit()
        await db.refresh(user)
        db.add(_identity(user.id, "apple", email="alice@privaterelay.appleid.com"))
        await db.commit()

        methods = await build_sign_in_methods(db, user)

        assert [m.provider for m in methods] == ["apple"]
        assert methods[0].display_identifier == "a***@privaterelay.appleid.com"

    async def test_phone_uses_phone_masker(self, db: AsyncSession):
        # Phone-only user — `users.phone` is set, the identity
        # row has no `email` column today. The masker picks up
        # `users.phone` via the `phone=...` argument in the
        # builder.
        user = _user(email=None, phone="+1234567890", password_hash=None)
        db.add(user)
        await db.commit()
        await db.refresh(user)
        db.add(_identity(user.id, "phone", email=None))
        await db.commit()

        methods = await build_sign_in_methods(db, user)

        assert [m.provider for m in methods] == ["phone"]
        assert methods[0].display_identifier == "+******7890"

    async def test_password_user_with_no_email_has_no_display_identifier(
        self, db: AsyncSession,
    ):
        # Defensive: a password user without an email (phone-only
        # at registration, then they added a password somehow) →
        # the password row's identifier is `None`. The UI renders
        # an empty subtitle rather than a half-masked address.
        user = _user(email=None, phone="+1234567890")
        db.add(user)
        await db.commit()
        await db.refresh(user)

        methods = await build_sign_in_methods(db, user)

        assert methods[0].provider == "password"
        assert methods[0].display_identifier is None

    async def test_ordering_respects_password_google_apple_phone(
        self, db: AsyncSession,
    ):
        # Insert identities in a deliberately scrambled order to
        # prove the sort key is the fixed one (password → google →
        # apple → phone), not insertion order or created_at.
        user = _user(email="alice@gmail.com", phone="+1234567890")
        db.add(user)
        await db.commit()
        await db.refresh(user)
        db.add(_identity(user.id, "phone", email=None))
        db.add(_identity(user.id, "apple", email="alice@apple.com"))
        db.add(_identity(user.id, "google", email="alice@gmail.com"))
        await db.commit()

        methods = await build_sign_in_methods(db, user)

        assert [m.provider for m in methods] == [
            "password", "google", "apple", "phone",
        ]

    async def test_unknown_provider_sorts_to_end_and_renders_raw(
        self, db: AsyncSession,
    ):
        # A future IdP ("github", "facebook", whatever) should
        # still surface in the list with the raw provider name —
        # the mobile client renders unknown providers with a
        # generic icon + the raw string.
        user = _user(email="alice@gmail.com")
        db.add(user)
        await db.commit()
        await db.refresh(user)
        db.add(_identity(user.id, "github", email="alice@github.com"))
        db.add(_identity(user.id, "google", email="alice@gmail.com"))
        await db.commit()

        methods = await build_sign_in_methods(db, user)

        # The known providers come first in the fixed order; the
        # unknown one trails at the end.
        assert [m.provider for m in methods] == ["password", "google", "github"]
        # The unknown provider's email is masked the same way the
        # known ones are.
        assert methods[-1].display_identifier == "a***@github.com"

    async def test_no_raw_provider_id_in_any_response(
        self, db: AsyncSession,
    ):
        # Security guard: the response must NEVER include the
        # `provider_user_id` (the IdP-side `sub` claim). That
        # value is enough to impersonate the user on the IdP if
        # it leaked, so it's strictly server-side.
        user = _user(email="alice@gmail.com")
        db.add(user)
        await db.commit()
        await db.refresh(user)
        secret_sub = f"google-sub-secret-{uuid.uuid4().hex[:8]}"
        db.add(AuthIdentity(
            user_id=user.id,
            provider="google",
            provider_user_id=secret_sub,
            email="alice@gmail.com",
            email_verified=True,
        ))
        await db.commit()

        methods = await build_sign_in_methods(db, user)

        # Serialise through the Pydantic model so we test what
        # actually goes on the wire, not just the in-memory shape.
        from app.schemas.user import UserResponse
        resp = UserResponse(
            id=user.id,
            email=user.email,
            full_name=user.full_name,
            role=user.role,
            is_active=user.is_active,
            created_at=user.created_at,
            is_email_verified=user.is_email_verified,
            sign_in_methods=methods,
        )
        # `model_dump()` of a Pydantic v2 model is a recursive dict.
        # Walk it and assert the secret never appears in any string
        # value.
        def _walk(node: object) -> None:
            if isinstance(node, dict):
                for v in node.values():
                    _walk(v)
            elif isinstance(node, list):
                for v in node:
                    _walk(v)
            elif isinstance(node, str):
                assert secret_sub not in node, (
                    f"secret sub leaked: {node!r}"
                )
        _walk(resp.model_dump())
