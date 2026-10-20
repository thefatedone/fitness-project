"""Adds the backend project root to sys.path so `from app...`
imports work without requiring `pip install -e .` (the project
uses `pyproject.toml` for pytest config but doesn't ship a
package manifest).

Also guards the test run against accidentally hitting the live
database. The full pipeline:

  1. Read `TEST_DATABASE_URL` from the environment (must be set
     by the test runner — `pytest` alone, with no env, aborts).
  2. Refuse to start if `TEST_DATABASE_URL` is missing or equal
     to the live `DATABASE_URL`. The equality check is the
     last-line-of-defence against a developer running
     `pytest tests/` in a shell that inherited the production
     env by accident.
  3. Rebind the SQLAlchemy engine + AsyncSessionLocal to the
     test URL BEFORE the first test imports the app's DB
     module. We swap the names on the live module so any later
     import of `from app.core.database import engine` resolves
     to the test engine.
  4. Create every table on the test DB at session start, drop
     them at session end. The lifecycle mirrors what
     `Base.metadata.create_all` would do in a fresh environment
     — no extra migration logic, no risk of drift.
  5. The redis client stays pointed at the live Redis. Each
     test in `test_google_auth.py` does its own
     `redis_client.disconnect()` + new connection cycle so the
     connect happens on the test's event loop; the keys are
     namespaced (`rl:photo:<ip>`) so cross-test contamination
     is a non-issue.
"""
import os
import sys

BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

import pytest
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.core.config import settings
from app.core.database import Base
from app.core import database as db_module


# ---------------------------------------------------------------------------
# Database isolation
# ---------------------------------------------------------------------------
#
# The order of operations here is the most important thing in the file:
# we validate the URL and rebind the engine BEFORE pytest collects the
# first test. If we did this inside a fixture, the original `engine`
# would already have been imported by the time we swap it, and asyncpg's
# connection pool would still point at the live DB. The session-scoped
# fixture below runs during `pytest`'s setup phase, which is before
# individual test modules are imported.

def _abort(message: str) -> None:
    """Hard-stop the test run with a clear message.

    Using `pytest.exit` propagates a non-zero exit code so CI fails
    loudly — the alternative (`pytest.skip` / `pytest.fail`) would
    either silently skip the suite or surface as a "failure" with
    a stack trace, neither of which communicates the actual issue
    (a misconfigured test environment)."""
    pytest.exit(message, returncode=2)


@pytest.fixture(scope="session", autouse=True)
def _isolate_test_database() -> None:
    """Validate `TEST_DATABASE_URL` and rebind the engine to it.

    The fixture is `autouse` so the validation runs for every
    test invocation, even ones that don't touch the DB (so a
    developer running `pytest tests/test_photo_analysis.py`
    still gets the safety check).

    We INTENTIONALLY do NOT run `create_all` here. Running an
    `engine.begin()` inside a sync fixture would open the pool
    on whatever event loop the fixture happens to land on,
    and pytest-asyncio's `function` scope then gives each test
    its own loop — asyncpg's connection pool is bound to the
    loop that opened it, so the first test would get
    "cannot perform operation: another operation is in
    progress" the moment it tries to use the engine. Instead,
    schema creation happens inside the app's lifespan
    (`Base.metadata.create_all` in `app/main.py`) when the
    first test triggers the FastAPI startup. That runs the DDL
    on the test's event loop, binding the pool to it. Tests
    that use the engine are responsible for disposing it
    between loops (the `http` fixture in `test_google_auth.py`
    does this).
    """
    test_url = os.environ.get("TEST_DATABASE_URL", "").strip()
    if not test_url:
        _abort(
            "TEST_DATABASE_URL is not set. Refusing to run the test "
            "suite against the live database.\n"
            "Set TEST_DATABASE_URL to a separate PostgreSQL database "
            "(e.g. postgresql+asyncpg://nutrimind:nutrimind@postgres:5432/nutrimind_test) "
            "and re-run."
        )

    # The guard against "TEST_DATABASE_URL == DATABASE_URL" is the
    # whole point of this fixture. Without it, a developer who
    # forgot to set TEST_DATABASE_URL and inherits DATABASE_URL
    # from .env would silently run tests against production data.
    live_url = settings.DATABASE_URL
    if test_url == live_url:
        _abort(
            f"TEST_DATABASE_URL matches DATABASE_URL ({live_url}). "
            "Tests must run against a separate database. Refusing to "
            "continue."
        )

    # Rebind the engine and session factory to the test URL.
    # `async_database_url` is a `@property` that reads from
    # `DATABASE_URL` on every call, so we only need to set the
    # one field. Anything in the app that calls
    # `from app.core.database import engine` will see the test
    # engine from this point on.
    settings.DATABASE_URL = test_url
    db_module.engine = create_async_engine(test_url, echo=False)
    db_module.AsyncSessionLocal = async_sessionmaker(
        db_module.engine, expire_on_commit=False
    )

    yield  # session-scoped fixture body

    # No drop_all on teardown — by the time this runs the engine
    # has been disposed by each per-test fixture, and we don't
    # want to spin up another event loop here. The test DB
    # (`nutrimind_test`) is reusable across test runs; if you
    # want a clean slate, drop it in psql and recreate:
    #   DROP DATABASE nutrimind_test;
    #   CREATE DATABASE nutrimind_test;
    # The lifespan's `create_all` will rebuild the schema on the
    # next test run.
