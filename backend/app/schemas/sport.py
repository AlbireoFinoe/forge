import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


IntensityType = Literal[
    "low",
    "moderate",
    "high",
]


class SportActivityCreate(BaseModel):
    sport_type: str = Field(
        min_length=2,
        max_length=50,
    )

    day_of_week: int = Field(
        ge=1,
        le=7,
    )

    duration_minutes: int = Field(
        ge=10,
        le=300,
    )

    intensity: IntensityType


class SportActivityUpdate(BaseModel):
    sport_type: str | None = Field(
        default=None,
        min_length=2,
        max_length=50,
    )

    day_of_week: int | None = Field(
        default=None,
        ge=1,
        le=7,
    )

    duration_minutes: int | None = Field(
        default=None,
        ge=10,
        le=300,
    )

    intensity: IntensityType | None = None


class SportActivityResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID

    sport_type: str
    day_of_week: int
    duration_minutes: int
    intensity: str

    created_at: datetime

    model_config = {
        "from_attributes": True
    }