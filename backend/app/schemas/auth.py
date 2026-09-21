import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator


class UserRegister(BaseModel):
    full_name: str = Field(
        min_length=2,
        max_length=120,
    )
    email: EmailStr
    password: str = Field(
        min_length=8,
        max_length=128,
    )

    @field_validator("full_name")
    @classmethod
    def normalize_full_name(
        cls,
        value: str,
    ) -> str:
        cleaned = " ".join(value.split())

        if len(cleaned) < 2:
            raise ValueError(
                "Full name must contain at least 2 characters"
            )

        return cleaned


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserUpdate(BaseModel):
    full_name: str = Field(
        min_length=2,
        max_length=120,
    )

    @field_validator("full_name")
    @classmethod
    def normalize_full_name(
        cls,
        value: str,
    ) -> str:
        cleaned = " ".join(value.split())

        if len(cleaned) < 2:
            raise ValueError(
                "Full name must contain at least 2 characters"
            )

        return cleaned


class UserResponse(BaseModel):
    id: uuid.UUID
    email: EmailStr
    full_name: str | None
    role: str
    is_active: bool
    created_at: datetime

    model_config = ConfigDict(
        from_attributes=True
    )


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class RefreshTokenRequest(BaseModel):
    refresh_token: str = Field(
        min_length=1
    )