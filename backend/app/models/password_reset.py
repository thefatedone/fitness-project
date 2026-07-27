from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    ForeignKey,
    Index,
    String,
)

from app.core.database import Base
import uuid
from datetime import datetime, timezone


def _utc_now():
    """Return current UTC time as naive datetime for database
    compatibility (matches the other models in this package)."""
    return datetime.now(timezone.utc).replace(tzinfo=None)


class PasswordResetCode(Base):
    """Single-use 6-digit code a user enters to prove ownership of
    their email when resetting a forgotten password.

    Lifecycle:
      * `forgot-password` route invalidates any existing unused
        codes for the user, then inserts a new one with
        `expires_at = now + 15 min`.
      * `verify-reset-code` route re-hashes the submitted code and
        compares — does *not* mark the code used; that's deferred to
        the `reset-password` route, so a typo on the entry screen
        doesn't burn the user's only shot.
      * `reset-password` route re-verifies the code (so the client
        can't skip the verify step), then sets `used = True` and
        updates `user.password_hash` in the same transaction.

    The 6-digit numeric code is hashed with the same bcrypt path
    as passwords before storage — that way a raw DB read (e.g. via
    a leaked backup) never reveals a still-valid code, and a
    "find a code" query can't be replayed to brute-force 10⁶
    candidates cheaply (bcrypt is intentionally slow).

    CASCADE on the `user_id` foreign key mirrors the rest of the
    schema: when the parent `users` row is hard-deleted, any
    outstanding reset codes vanish with it.
    """

    __tablename__ = "password_reset_codes"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))

    user_id = Column(
        String,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )

    # bcrypt-hashed 6-digit code (10⁶-key space; same defensive
    # posture as `users.password_hash`).
    code_hash = Column(String, nullable=False)

    # Set to `now + 15 min` at creation. The verify + reset routes
    # both treat `expires_at < now` as "no longer valid".
    expires_at = Column(DateTime, nullable=False)

    # A code is redeemed exactly once. `reset-password` flips this
    # from False to True; the verify route leaves it alone.
    used = Column(Boolean, default=False, nullable=False)

    created_at = Column(DateTime, default=_utc_now, nullable=False)

    # Indexes that match the query patterns of the three routes:
    #   * `verify-reset-code` and `reset-password` look up "the
    #     most recent non-used, non-expired code for this user"
    #     → composite (user_id, expires_at) descending.
    #   * `forgot-password`'s "invalidate all previous codes" runs
    #     an UPDATE … WHERE user_id = ? — covered by the user_id
    #     index alone.
    __table_args__ = (
        Index("ix_password_reset_codes_user_id", "user_id"),
        Index("ix_password_reset_codes_expires_at", "expires_at"),
    )

