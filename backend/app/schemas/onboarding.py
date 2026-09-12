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

    secondary_goals: list[GoalType] = Field(
        default_factory=list,
        max_length=2,
    )

    @model_validator(mode="after")
    def validate_secondary_goals(self):
        if len(self.secondary_goals) != len(
            set(self.secondary_goals)
        ):
            raise ValueError(
                "secondary_goals cannot contain duplicates"
            )

        if self.primary_goal in self.secondary_goals:
            raise ValueError(
                "primary_goal cannot also be a secondary goal"
            )

        return self


class GoalResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    primary_goal: str
    secondary_goals: list[str] = Field(
        default_factory=list
    )
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
    sports_configured: bool

    created_at: datetime
    updated_at: datetime


class OnboardingResponse(BaseModel):
    goal: GoalResponse | None
    training_preferences: TrainingPreferencesResponse | None