"""Unit tests for the provider-agnostic identity service
`app.services.auth_identity.get_or_create_user_from_identity`.

The service function is the single point where social / phone
identity → user lookup / creation happens. It owns the four
behaviours that matter for security and linking UX:

  * `(provider, provider_user_id)` is a globally-unique handle
    into our user table — same Google `sub` twice must produce
    the same user.
  * Verified-email linking — when the IdP says
    `email_verified=true`, an existing user with that email gets
    a new identity row attached; otherwise a new user is
    created.
  * Unverified-email refusal — a token whose email is present
    but `email_verified=False` is treated as "no email at all"
    rather than as a link candidate, so an attacker can't
    squat on someone else's address.
  * Display-name synthesis — the IdP didn't have to give us a
    name; the service function still produces a non-empty
    `User.full_name`.

A SQLite in-memory async session gives us a real DB (FK
constraints, unique constraints, the CASCADE on
`users.id` deletion) without standing up a Postgres test
container.
"""
from __future__ import annotations

import os
import uuid
from typing import AsyncIterator

import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

# Ensure the model imports are picked up before `Base.metadata`
# is referenced — without this, the in-memory schema would be
# empty because the auth_identity + user models would never
# have been registered with `Base`.
from app.core.config import settings  # noqa: F401  (settings must load before models)
from app.core.database import Base
from app.models.auth_identity import AuthIdentity
from app.models.user import User
from app.services.auth_identity import get_or_create_user_from_identity


# `aiosqlite` is a test-only dependency — the runtime app uses
# `asyncpg` against Postgres. The service function doesn't care
# which dialect, so SQLite is fine for the unit tests.
import aiosqlite  # noqa: F401  (registers the SQLite dialect)


def _sqlite_url() -> str:
    """Per-test in-memory SQLite URL. Using a fresh URL per test
    is the standard recipe for a fully-isolated DB; sharing one
    across tests would force us to drop / recreate rows by hand
    and still leak the `users` rows we care about."""
    return f"sqlite+aiosqlite:///:memory:"


@pytest_asyncio.fixture
async def db() -> AsyncIterator[AsyncSession]:
    """Per-test in-memory async session with the full schema
    created. `Base.metadata.create_all` runs against the
    connection so the auth_identities + users tables exist for
    every test."""
    engine = create_async_engine(_sqlite_url(), echo=False)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    SessionLocal = async_sessionmaker(engine, expire_on_commit=False)
    async with SessionLocal() as session:
        yield session
    await engine.dispose()


# ---------------------------------------------------------------------------
# 1. New user — no existing identity, no email match
# ---------------------------------------------------------------------------

async def test_new_user_with_no_email_creates_user_and_identity(db: AsyncSession):
    user, created = await get_or_create_user_from_identity(
        db, "google", f"sub-{uuid.uuid4()}",
    )
    assert created is True
    assert user.id  # assigned by the model's UUID default
    assert user.password_hash is None  # social-only user
    assert user.email is None  # no verified email
    assert user.full_name == "User"  # synthetic fallback


async def test_new_user_with_verified_email_uses_email_local_part_as_name(
    db: AsyncSession,
):
    user, created = await get_or_create_user_from_identity(
        db,
        "google", f"sub-{uuid.uuid4()}",
        email="alice@example.com",
        email_verified=True,
        # no display_name — synthesise from the email local part
    )
    assert created is True
    assert user.email == "alice@example.com"
    assert user.full_name == "Alice"  # capitalised local part


async def test_new_user_with_explicit_display_name_wins(db: AsyncSession):
    user, created = await get_or_create_user_from_identity(
        db,
        "google", f"sub-{uuid.uuid4()}",
        email="alice@example.com",
        email_verified=True,
        display_name="Alice Q. User",
    )
    assert created is True
    assert user.full_name == "Alice Q. User"


# ---------------------------------------------------------------------------
# 2. Existing identity — same `(provider, provider_user_id)` re-signs in
# ---------------------------------------------------------------------------

async def test_existing_identity_returns_same_user_no_new_row(db: AsyncSession):
    sub = f"sub-{uuid.uuid4()}"
    user1, created1 = await get_or_create_user_from_identity(
        db, "google", sub,
        email="alice@example.com", email_verified=True,
    )
    assert created1 is True

    # Second call with the same `sub` — no matter what email /
    # name the new token claims, the user is the one we created
    # on the first call.
    user2, created2 = await get_or_create_user_from_identity(
        db, "google", sub,
        email="different@example.com", email_verified=True,
        display_name="Different Name",
    )
    assert created2 is False
    assert user2.id == user1.id
    # The pre-existing user record is NOT mutated by the new
    # call — we treat the first link as authoritative for name /
    # email until the user themselves updates their profile.
    assert user2.email == "alice@example.com"
    assert user2.full_name == "Alice"


# ---------------------------------------------------------------------------
# 3. Link by verified email — different IdP, same email
# ---------------------------------------------------------------------------

async def test_verified_email_links_to_existing_user(db: AsyncSession):
    # Seed an existing email/password user.
    existing = User(
        email="alice@example.com",
        password_hash="bcrypt-placeholder",
        full_name="Alice Existing",
    )
    db.add(existing)
    await db.commit()
    await db.refresh(existing)

    # Google sign-in with the SAME email, verified. The service
    # should attach a new identity to the existing user — not
    # create a duplicate.
    google_sub = f"sub-{uuid.uuid4()}"
    user, created = await get_or_create_user_from_identity(
        db, "google", google_sub,
        email="Alice@Example.com",  # mixed case to test normalisation
        email_verified=True,
        display_name="Alice From Google",
    )
    assert created is False
    assert user.id == existing.id
    # The user row itself is not mutated — pre-existing full_name
    # wins over the IdP's claim, because the user typed it
    # themselves.
    assert user.full_name == "Alice Existing"
    assert user.email == "alice@example.com"

    # And the identity row was actually created and bound to
    # the existing user.
    identity = (
        await db.execute(
            # Use a fresh query — the in-memory session still
            # has the row from the link path, but a SELECT proves
            # it was committed.
            __import__("sqlalchemy").select(AuthIdentity).where(
                AuthIdentity.provider == "google",
                AuthIdentity.provider_user_id == google_sub,
            )
        )
    ).scalar_one()
    assert identity.user_id == existing.id
    assert identity.email == "alice@example.com"
    assert identity.email_verified is True


# ---------------------------------------------------------------------------
# 4. Unverified email does NOT link — a brand-new user is created
# ---------------------------------------------------------------------------

async def test_unverified_email_creates_new_user_instead_of_linking(
    db: AsyncSession,
):
    # Seed an existing email/password user.
    existing = User(
        email="alice@example.com",
        password_hash="bcrypt-placeholder",
        full_name="Alice Existing",
    )
    db.add(existing)
    await db.commit()
    await db.refresh(existing)

    # Google sign-in with the SAME email but `email_verified=False`.
    # The spec is explicit: never link by an unverified email.
    # A new user is created instead, with no email attached.
    user, created = await get_or_create_user_from_identity(
        db, "google", f"sub-{uuid.uuid4()}",
        email="alice@example.com",
        email_verified=False,
        display_name="Impostor",
    )
    assert created is True
    assert user.id != existing.id
    # The new user has no email — we ignore the IdP's claim
    # entirely when it's unverified.
    assert user.email is None
    # The original user is untouched.
    assert existing.email == "alice@example.com"


# ---------------------------------------------------------------------------
# 5. Defensive: empty / None provider arguments raise ValueError
# ---------------------------------------------------------------------------

async def test_empty_provider_raises(db: AsyncSession):
    with pytest.raises(ValueError):
        await get_or_create_user_from_identity(db, "", "sub-x")


async def test_empty_provider_user_id_raises(db: AsyncSession):
    with pytest.raises(ValueError):
        await get_or_create_user_from_identity(db, "google", "")
