import asyncio
from logging.config import fileConfig

from sqlalchemy import pool
from sqlalchemy.engine import Connection
from sqlalchemy.ext.asyncio import async_engine_from_config

from alembic import context

# import models for autogenerate support
from app.models import *
from app.core.database import Base
from app.core.config import settings

# this is the Alembic Config object, which provides
# access to the values within the .ini file in use.
config = context.config

# Interpret the config file for Python logging.
# This line sets up loggers basically.
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Single source of truth for the DB URL: the same `Settings` singleton
# the FastAPI app itself loads from `.env` via pydantic-settings. We
# override the (placeholder / hardcoded) value in `alembic.ini` with
# the real one at runtime so:
#   * Dev / prod / staging never need a separate alembic.ini edit.
#   * The async driver (`postgresql+asyncpg://`) is honoured — the
#     sync `engine_from_config` default can't consume an async URL.
# The hardcoded `sqlalchemy.url = postgresql+asyncpg://...:secret@localhost`
# line in alembic.ini is left in place as a placeholder / a hint to
# human readers (and so the `alembic` CLI doesn't crash on a missing
# key during config parsing) but is overridden here before any
# engine is built.
config.set_main_option("sqlalchemy.url", settings.DATABASE_URL)

# add your model's MetaData object here
# for 'autogenerate' support
target_metadata = Base.metadata


def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode.

    This configures the context with just a URL
    and not an Engine, though an Engine is acceptable
    here as well.  By skipping the Engine creation
    we don't even need a DBAPI to be available.

    Calls to context.execute() here emit the given string to the
    script output.

    """
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()


def _do_run_migrations(connection: Connection) -> None:
    """Sync helper that runs the actual Alembic migration logic against
    a single connection. Lives inside `run_migrations_online` so we
    can drive it via `connection.run_sync(...)` from the async path.

    This is the standard pattern recommended in the SQLAlchemy +
    Alembic async docs: Alembic's `context.run_migrations()` is
    fundamentally synchronous, so it has to be invoked from inside a
    sync function that takes a single `Connection`. The async engine's
    `run_sync` adapts between async event loop and this sync function
    without us having to write a greenlet-friendly version of
    `context.run_migrations` ourselves.
    """
    context.configure(connection=connection, target_metadata=target_metadata)
    with context.begin_transaction():
        context.run_migrations()


async def run_async_migrations() -> None:
    """Async entry point that creates the async engine and runs the
    migrations on a single connection. Mirrors the structure of the
    canonical Alembic async template (see
    https://alembic.sqlalchemy.org/en/latest/cookbook.html#using-asyncio
    -with-alembic).
    """
    connectable = async_engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    async with connectable.connect() as connection:
        await connection.run_sync(_do_run_migrations)
    await connectable.dispose()


def run_migrations_online() -> None:
    """Run migrations in 'online' mode.

    In this scenario we need to create an Engine
    and associate a connection with the context.

    The body is now async; the synchronous `context.run_migrations()`
    inside the greenlet-safe helper `connection.run_sync(...)` so it
    can run from a sync function called via the asyncpg / greenlet
    bridge. `asyncio.run` blocks the main thread until the migration
    completes — which is exactly what `alembic upgrade head` expects
    (it's already a synchronous CLI from the caller's perspective).
    """
    asyncio.run(run_async_migrations())


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
