import uuid
from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field


class ProfileUpdate(BaseModel):
    display_name: str | None = Field(
        default=None,
        min_length=1,
        max_length=100,
    )

    birth_date: date | None = None

    gender: str | None = Field(
        default=None,
        max_length=30,
    )

    height_cm: float | None = Field(
        default=None,
        gt=0,
        le=300,
    )

    current_weight_kg: float | None = Field(
        default=None,
        gt=0,
        le=500,
    )

    unit_system: str | None = Field(
        default=None,
        pattern="^(metric|imperial)$",
    )

    experience_level: str | None = Field(
        default=None,
        pattern="^(beginner|intermediate|advanced)$",
    )


class ProfileResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID

    display_name: str | None
    birth_date: date | None
    gender: str | None

    height_cm: float | None
    current_weight_kg: float | None

    unit_system: str
    experience_level: str | None

    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(
        from_attributes=True
    )