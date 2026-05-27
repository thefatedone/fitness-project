from pydantic import BaseModel, EmailStr
from typing import Optional


class ContactFormIn(BaseModel):
    first_name: str
    last_name: str
    email: EmailStr
    phone: Optional[str] = None
    purpose: str
    message: Optional[str] = None