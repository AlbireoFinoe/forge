import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field, model_validator


GoalType = Literal[
    "muscle_gain",
    "strength",
    "fat_loss",
    "general_fitness",
    "hybrid",
]


class GoalUpdate(BaseModel):
    primary_goal: GoalType


class GoalResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    primary_goal: str
    created_at: datetime
    updated_at: datetime

    model_config = {
        "from_attributes": True
    }


class TrainingPreferencesUpdate(BaseModel):
    days_per_week: int = Field(
        ge=1,
        le=7,
    )

    session_duration_minutes: int = Field(
        ge=15,
        le=240,
    )

    available_days: list[int]

    no_dedicated_leg_day: bool = False
    arm_specialization: bool = False

    @model_validator(mode="after")
    def validate_available_days(self):
        if len(self.available_days) != len(set(self.available_days)):
            raise ValueError(
                "available_days cannot contain duplicates"
            )

        if any(
            day < 1 or day > 7
            for day in self.available_days
        ):
            raise ValueError(
                "available_days must contain values from 1 to 7"
            )

        if len(self.available_days) != self.days_per_week:
            raise ValueError(
                "available_days count must match days_per_week"
            )

        return self


class TrainingPreferencesResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID

    days_per_week: int
    session_duration_minutes: int

    available_days: list[int]

    no_dedicated_leg_day: bool
    arm_specialization: bool

    created_at: datetime
    updated_at: datetime


class OnboardingResponse(BaseModel):
    goal: GoalResponse | None
    training_preferences: TrainingPreferencesResponse | None