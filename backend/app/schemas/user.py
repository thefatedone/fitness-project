import json
from typing import List, Optional
from pydantic import BaseModel, field_validator
from datetime import datetime

from app.core.security import validate_password_strength


def _coerce_tags(v):
    """Accept list[str] OR a comma-separated string. Return a clean list[str] or None.

    - Trims each item, drops blanks
    - Deduplicates case-insensitively, preserving the first-seen casing
    - Returns None when the input is empty / None / not a recognised shape, so the
      column is cleared on save.
    """
    if v is None or v == "":
        return None
    if isinstance(v, str):
        items = [s.strip() for s in v.split(",") if s.strip()]
    elif isinstance(v, list):
        items = [str(s).strip() for s in v if str(s).strip()]
    else:
        return None
    seen: set[str] = set()
    deduped: list[str] = []
    for item in items:
        key = item.lower()
        if key not in seen:
            seen.add(key)
            deduped.append(item)
    return deduped or None


class UserBase(BaseModel):
    email: Optional[str] = None
    phone: Optional[str] = None
    name: str


class UserUpdate(BaseModel):
    email: Optional[str] = None
    phone: Optional[str] = None
    full_name: Optional[str] = None
    date_of_birth: Optional[str] = None
    sex: Optional[str] = None
    height: Optional[float] = None
    current_weight: Optional[float] = None
    target_weight: Optional[float] = None
    activity_level: Optional[str] = None
    primary_goal: Optional[str] = None
    dietary_preferences: Optional[List[str]] = None
    food_allergies: Optional[List[str]] = None
    weight_loss_pace: Optional[float] = None
    profile_photo: Optional[str] = None

    @field_validator("dietary_preferences", "food_allergies", mode="before")
    @classmethod
    def _coerce_tags_field(cls, v):
        return _coerce_tags(v)


class PasswordChangeRequest(BaseModel):
    """Body for `PUT /users/me/password`.

    `current_password` is verified server-side against the user's
    stored bcrypt hash before the swap — the endpoint isn't a password-
    reset flow, just a "I know my old password and want to set a new
    one" flow. `new_password` runs the same strength rules as
    registration via the shared `validate_password_strength` helper.
    """
    current_password: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def _validate_new_password_strength(cls, v: str) -> str:
        # Reuse the same rules as registration so the mobile app
        # gives the user consistent feedback across both flows. On
        # failure, Pydantic turns the ValueError into a 422 with
        # this string in the `msg` of the first validation error,
        # which the mobile client's `ApiException.fromDioError`
        # extracts and surfaces in a SnackBar.
        err = validate_password_strength(v)
        if err:
            raise ValueError(err)
        return v


class AccountDeletionRequest(BaseModel):
    """Body for `DELETE /users/me`.

    Deletion is destructive and irreversible, so the endpoint
    requires password re-confirmation as a safety gate — same
    principle as `PasswordChangeRequest`'s `current_password` check.
    Wrong password → 400 with a Russian detail; nothing in the
    database or filesystem is touched until the gate passes.
    """
    password: str


class VerifyEmailRequest(BaseModel):
    """Body for `POST /auth/verify-email`. Just the 6-digit code the
    user typed from the email — the route already knows which user
    is asking (via the JWT), so no email field is needed here.
    """
    code: str


class UserResponse(BaseModel):
    id: str
    email: Optional[str]
    full_name: str
    role: str
    phone: Optional[str] = None
    date_of_birth: Optional[datetime] = None
    sex: Optional[str] = None
    height: Optional[float] = None
    current_weight: Optional[float] = None
    target_weight: Optional[float] = None
    activity_level: Optional[str] = None
    primary_goal: Optional[str] = None
    dietary_preferences: Optional[str] = None
    food_allergies: Optional[str] = None
    weight_loss_pace: Optional[float] = None
    bmr: Optional[float] = None
    tdee: Optional[float] = None
    daily_cal_target: Optional[int] = None
    protein_target: Optional[float] = None
    carbs_target: Optional[float] = None
    fat_target: Optional[float] = None
    is_active: bool = True
    created_at: datetime
    profile_photo: Optional[str] = None
    # Email-verification status — the mobile / web clients read this
    # to drive a "verify your email" reminder banner. The column on
    # the User model is nullable=False (a real boolean), so when it
    # comes back from a `from_attributes` read this is `bool`, never
    # `None`. We still type it as `bool` (not `Optional[bool]`) here.
    is_email_verified: bool = False

    @field_validator("dietary_preferences", "food_allergies", mode="before")
    @classmethod
    def _normalize_tags_to_csv(cls, v):
        """Guarantee these two fields serialize as CSV strings or ``None`` — never as a list.

        Why this exists
        ---------------
        The DB columns are declared as ``Text`` (string), but some production /
        dev rows contain a *JSON-encoded* array (e.g. ``'["Milk","Sugar"]'``)
        from an older client. With ``from_attributes = True`` enabled,
        Pydantic only validates types it's asked to coerce — when the declared
        type is a list and the runtime value is already a list, the list is
        passed straight through to the JSON response. Strongly-typed clients
        (e.g. the Flutter app, which casts these fields to ``String?``) then
        crash on the unexpected JSON array.

        Inputs accepted and their handling:
          * ``None``                  → returned as-is.
          * ``list`` of strings       → items trimmed, empties dropped,
                                        joined with ``","``. Empty result → ``None``.
          * ``str`` starting with ``[`` →
                                        ``json.loads`` is attempted. If it yields
                                        a list, the same join-and-clean logic
                                        applies. If parsing fails or the result
                                        is not a list, we fall through and treat
                                        the string as a plain CSV.
          * Other ``str``             → trimmed; empty becomes ``None``.
          * Anything else             → best-effort ``str()`` then ``None`` if empty.
        """
        if v is None:
            return None

        # Case 1: input is already a Python list (the path that currently leaks).
        if isinstance(v, list):
            items = [str(s).strip() for s in v if s is not None and str(s).strip()]
            return ",".join(items) if items else None

        # Case 2 & 3: input is a string — possibly a JSON-shaped array.
        if isinstance(v, str):
            s = v.strip()
            if not s:
                return None
            if s.startswith("["):
                try:
                    parsed = json.loads(s)
                except (json.JSONDecodeError, ValueError):
                    parsed = None
                if isinstance(parsed, list):
                    items = [
                        str(x).strip() for x in parsed if x is not None and str(x).strip()
                    ]
                    return ",".join(items) if items else None
            # Fall-through: treat as a plain CSV (or single-tag) string.
            return s

        # Defensive last-resort so the wire format stays predictable.
        coerced = str(v).strip()
        return coerced or None

    class Config:
        from_attributes = True
