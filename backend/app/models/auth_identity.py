from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    ForeignKey,
    Index,
    String,
    UniqueConstraint,
)

from app.core.database import Base
import uuid
from datetime import datetime, timezone


def _utc_now():
    """Naive UTC timestamp — matches the convention in
    `password_reset.py` and `user.py` so the DB driver never has
    to translate tz-aware vs tz-naive at INSERT/UPDATE time."""
    return datetime.now(timezone.utc).replace(tzinfo=None)


class AuthIdentity(Base):
    """A link between a [User] and a sign-in method.

    Multiple identities can point at the same user — a user who
    registered with email/password and later linked Google would
    have one row here for the Google link; a user who signs in
    only with Google has one row here and `users.password_hash`
    is NULL. The (provider, provider_user_id) pair is globally
    unique so the same Google account can never silently bind to
    two of our users.

    Email is stored on this row (not just on `users`) because the
    token-derived email and the user-typed email are different
    things — the token email is what the IdP asserted, the user
    email is what the user picked. We keep the IdP email so a
    later "is this the same person?" check has the original
    assertion to lean on. `email_verified` records the IdP's
    `email_verified` claim at the time of the link — we never
    link by an unverified email (see the service function), but
    we still capture the bit so the rest of the system can decide
    whether to auto-mark `users.is_email_verified` when the IdP
    itself vouches for it.

    The unique constraint is the only index the service function
    ever queries by — `find_by_provider(provider, provider_user_id)`
    runs as an indexed point lookup. `user_id` is indexed too
    because a future "list providers linked to this account" UI
    will need it.
    """

    __tablename__ = "auth_identities"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))

    # CASCADE on the FK mirrors the rest of the schema: when a
    # `users` row is hard-deleted, its identities vanish too.
    user_id = Column(
        String,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )

    # The provider wire name: `"google"`, `"apple"`, `"phone"`.
    # Kept as a plain `String` (not an Enum) so adding a new
    # provider is a code-and-migration change, not a schema
    # reshape. The service function treats it as a free-form
    # string so new providers can plug in without altering this
    # column.
    provider = Column(String, nullable=False)

    # The IdP's stable identifier for this user — the `sub` claim
    # of a Google ID token, the `sub` claim of an Apple ID
    # token, the phone number for SMS. Combined with `provider`
    # it's globally unique.
    provider_user_id = Column(String, nullable=False)

    # Snapshot of the email the IdP returned at link time, if any.
    # Nullable: Apple's `email` is opt-in, and phone-login has
    # no email at all. The user row's own `email` column is
    # separate and authoritative for the "what should we send
    # receipts to" question.
    email = Column(String, nullable=True)

    # Whether the IdP's token said `email_verified=true`. We
    # never link by an unverified email (see
    # `get_or_create_user_from_identity`), but we still record
    # the bit for downstream UX.
    email_verified = Column(Boolean, default=False, nullable=False)

    created_at = Column(DateTime, default=_utc_now, nullable=False)

    __table_args__ = (
        # The whole point of the table: enforce "one identity
        # per IdP user" at the DB layer so a race between two
        # concurrent `/auth/google` calls can't accidentally
        # create two `users` for the same Google `sub`.
        UniqueConstraint(
            "provider", "provider_user_id",
            name="uq_auth_identities_provider_provider_user_id",
        ),
        Index("ix_auth_identities_user_id", "user_id"),
    )
