from pydantic import BaseModel


class UserCreate(BaseModel):
    email: str | None = None
    phone: str | None = None
    password: str
    name: str


class UserLogin(BaseModel):
    email: str | None = None
    phone: str | None = None
    password: str


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


class UserResponse(BaseModel):
    id: str
    email: str | None
    name: str
    role: str