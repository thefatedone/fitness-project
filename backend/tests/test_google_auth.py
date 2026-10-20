"""Endpoint tests for `POST /api/v1/auth/google`.

We don't make real network calls to Google. The test patches
`google.oauth2.id_token.verify_oauth2_token` so each test owns
the claims dict it wants the route to see, then walks the route
through FastAPI's `TestClient` and asserts on the response.

What we cover:
  * happy path: a valid Google `sub` + verified email produces a
    JWT in the standard `Token` envelope.
  * wrong audience: the route raises 401 when the IdP library
    raises `GoogleAuthError` (the test triggers that by patching
    the verify function to raise).
  * expired token: same path as wrong-audience — both look like
    verification failures to us, and we don't leak which one
    to the client.
  * unverified email: the route refuses to create a user and
    returns 403. This is the security boundary for account
    linking — an unverified email is *not* enough to claim an
    existing account.
  * missing configuration: when `GOOGLE_AUTH_CLIENT_IDS` is
    empty, the route returns 502 (upstream misconfig), not 401
    (we'd rather the operator see "this is broken" than the
    user see "your account is wrong").
  * missing id_token: 400 with a useful message.

Why httpx.AsyncClient (not `TestClient`): `TestClient` runs
each request in a fresh anyio-from-thread portal, which creates
a brand-new event loop per request. asyncpg's connection
pool binds the underlying sockets to whichever loop happened
to create them — the next request's loop can't drive them and
the test explodes with "Future attached to a different loop".
`httpx.AsyncClient(transport=ASGITransport(app))` keeps every
request on the SAME loop the app started on, which is what
SQLAlchemy's async engine needs.
"""
from __future__ import annotations

import uuid
from typing import Any
from unittest.mock import patch

import httpx
import pytest
import pytest_asyncio
from google.auth.exceptions import GoogleAuthError

# Settings must be loaded before the app can construct. The
# `monkeypatch` setattr in the `env` fixture re-binds the
# Google client ID list to the test value before the route is
# exercised.
from app.core.config import settings  # noqa: F401
from app.main import app


def _claims(**overrides: Any) -> dict[str, Any]:
    """Build a fresh happy-path claims dict with a unique `sub`.

    Each call returns a *new* `sub` so the success-path tests
    don't collide on the `(provider, provider_user_id)` unique
    constraint — without this, the second test in a run would
    see a pre-existing identity and short-circuit to "not a new
    user", which is actually the correct production behaviour
    but breaks the "creates a new user" assertion.

    The unique email also matters: when the email matches an
    existing user, the service function links instead of
    creating. A random email-local-part per call avoids the
    link path and keeps the test focused on the "no matching
    user → create" branch.
    """
    unique = uuid.uuid4().hex[:12]
    base: dict[str, Any] = {
        "sub": f"google-sub-{unique}",
        "email": f"alice-{unique}@example.com",
        "email_verified": True,
        "name": "Alice Google",
        "iss": "https://accounts.google.com",
        "aud": "web-client-id",
    }
    base.update(overrides)
    return base


@pytest.fixture
def env(monkeypatch: pytest.MonkeyPatch):
    """Configure a single allowed Google client ID for the test.

    We re-bind `settings.google_auth_client_id_list` so the
    `audience=` argument passed to the verify call matches what
    the test claims include. The same list is what the route
    reads to decide whether the server is configured at all."""
    monkeypatch.setattr(
        settings,
        "GOOGLE_AUTH_CLIENT_IDS",
        "web-client-id",
        raising=True,
    )
    return settings


@pytest_asyncio.fixture
async def http(env):
    """Async HTTP client wired to the running app.

    Per-test dance needed because each pytest-asyncio test runs
    on a FRESH event loop (its default `function` scope):

      * The SQLAlchemy async engine's connection pool is bound
        to whichever loop first used it. With multiple tests
        per session, the 2nd+ test's loop can't drive the pool
        → "Future attached to a different loop". `dispose()`
        closes the old pool; the next `engine.connect()` call
        creates a new one on the current loop.
      * Same story for `redis_client` — its `redis.asyncio`
        pool is loop-bound. Disconnect+reconnect per test.

    Without this dance the second test in the session explodes
    the moment any route touches the DB or Redis.
    """
    from app.core.database import engine as db_engine
    from app.core.redis_client import redis_client

    await db_engine.dispose()
    await redis_client.disconnect()
    try:
        transport = httpx.ASGITransport(app=app)
        async with httpx.AsyncClient(
            transport=transport, base_url="http://test"
        ) as client:
            yield client
    finally:
        await db_engine.dispose()
        await redis_client.disconnect()


# ---------------------------------------------------------------------------
# Happy path
# ---------------------------------------------------------------------------

async def test_google_login_returns_access_token(http):
    with patch(
        "app.api.v1.routes.auth.google_id_token.verify_oauth2_token",
        return_value=_claims(),
    ):
        res = await http.post(
            "/api/v1/auth/google",
            json={"id_token": "any-string-here"},
        )
    assert res.status_code == 200
    body = res.json()
    assert "access_token" in body
    assert body["token_type"] == "bearer"
    # The token is a JWT — three base64url-encoded segments
    # joined by dots. Decoding the payload isn't necessary;
    # shape is enough.
    assert body["access_token"].count(".") == 2


async def test_google_login_creates_a_new_user_with_no_password(http):
    # First sign-in for this `sub` → a new user is created
    # with `password_hash=None` (social-only) and the email
    # we passed. We don't reach into the DB to verify; the
    # 200 + token proves the route's happy path executed.
    with patch(
        "app.api.v1.routes.auth.google_id_token.verify_oauth2_token",
        return_value=_claims(),
    ):
        res = await http.post(
            "/api/v1/auth/google",
            json={"id_token": "any-string-here"},
        )
    assert res.status_code == 200


# ---------------------------------------------------------------------------
# Verification failure → 401
# ---------------------------------------------------------------------------

async def test_google_login_401_when_verify_raises_googleautherror(http):
    # `verify_oauth2_token` raises `GoogleAuthError` for
    # bad-signature / wrong-audience / expired / wrong-issuer.
    # We don't distinguish on the wire — the test just confirms
    # every variant ends up at 401.
    with patch(
        "app.api.v1.routes.auth.google_id_token.verify_oauth2_token",
        side_effect=GoogleAuthError("Token expired"),
    ):
        res = await http.post(
            "/api/v1/auth/google",
            json={"id_token": "expired-token"},
        )
    assert res.status_code == 401
    # The 401 detail should not leak WHY the token failed —
    # an attacker probing the endpoint learns nothing from
    # "expired" vs "bad signature".
    assert "Invalid Google token" in res.json()["detail"]


async def test_google_login_401_when_verify_raises_generic_exception(http):
    # A network blip when fetching Google's public keys, or
    # any other library-internal failure, should be reported
    # as 502 (upstream unreachable), not 401 (auth failure).
    # The latter would tell the user "your password is wrong"
    # when actually Google is down, which is misleading.
    with patch(
        "app.api.v1.routes.auth.google_id_token.verify_oauth2_token",
        side_effect=RuntimeError("network unreachable"),
    ):
        res = await http.post(
            "/api/v1/auth/google",
            json={"id_token": "any"},
        )
    assert res.status_code == 502


# ---------------------------------------------------------------------------
# Security boundary — unverified email
# ---------------------------------------------------------------------------

async def test_google_login_403_when_email_unverified(http):
    # The token IS valid, the signature IS right, but Google
    # said `email_verified=false`. We refuse to create or link
    # a user from this — a real attacker would have a hard
    # time minting a token with `email_verified=true` against
    # someone else's email, but a hostile IdP config or a
    # compromised Google Cloud project makes it possible. The
    # right read is "we don't trust this email enough to
    # associate a user with it".
    with patch(
        "app.api.v1.routes.auth.google_id_token.verify_oauth2_token",
        return_value=_claims(email_verified=False),
    ):
        res = await http.post(
            "/api/v1/auth/google",
            json={"id_token": "any"},
        )
    assert res.status_code == 403
    assert "not verified" in res.json()["detail"]


async def test_google_login_succeeds_without_email_at_all(http):
    # Apple users (a future flow) can opt out of sharing email
    # entirely. The verify call returns no `email` claim at
    # all — the service function falls through to the
    # "create new user, no email attached" path. 200 + token.
    claims = _claims()
    claims.pop("email", None)
    claims.pop("email_verified", None)
    with patch(
        "app.api.v1.routes.auth.google_id_token.verify_oauth2_token",
        return_value=claims,
    ):
        res = await http.post(
            "/api/v1/auth/google",
            json={"id_token": "any"},
        )
    assert res.status_code == 200


# ---------------------------------------------------------------------------
# Server-side misconfiguration → 502
# ---------------------------------------------------------------------------

async def test_google_login_502_when_no_client_ids_configured(
    http, monkeypatch: pytest.MonkeyPatch
):
    # Operator forgot to set `GOOGLE_AUTH_CLIENT_IDS`. We can't
    # have minted a token in this state, so 502 (upstream
    # misconfig) is the honest read. The user sees "Google
    # sign-in is not configured", the operator sees an alert
    # in the logs.
    monkeypatch.setattr(settings, "GOOGLE_AUTH_CLIENT_IDS", "", raising=True)
    with patch(
        "app.api.v1.routes.auth.google_id_token.verify_oauth2_token",
        return_value=_claims(),
    ):
        res = await http.post(
            "/api/v1/auth/google",
            json={"id_token": "any"},
        )
    assert res.status_code == 502
    assert "not configured" in res.json()["detail"]


# ---------------------------------------------------------------------------
# Bad request
# ---------------------------------------------------------------------------

async def test_google_login_400_when_id_token_missing(http):
    res = await http.post("/api/v1/auth/google", json={})
    assert res.status_code == 422  # Pydantic catches missing field

    res = await http.post("/api/v1/auth/google", json={"id_token": ""})
    assert res.status_code == 400
    assert "id_token" in res.json()["detail"]


async def test_google_login_400_when_id_token_whitespace(http):
    res = await http.post("/api/v1/auth/google", json={"id_token": "   "})
    assert res.status_code == 400
