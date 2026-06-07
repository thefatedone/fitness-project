from sqlalchemy import Column, String, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from app.core.database import Base
import uuid
from datetime import datetime, timezone


def utc_now():
    """Return current UTC time as naive datetime for database compatibility."""
    return datetime.now(timezone.utc).replace(tzinfo=None)


class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id             = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id        = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    conversation_id = Column(String, nullable=True)  # null means no conversation grouping
    role           = Column(String, nullable=False)
    content        = Column(Text, nullable=False)
    created_at     = Column(DateTime, default=utc_now)

    user = relationship("User", back_populates="chat_messages")