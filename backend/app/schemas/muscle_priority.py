import uuid
from typing import Literal

from pydantic import BaseModel


PriorityType = Literal[
    "high",
    "normal",
    "maintenance",
]


class MuscleGroupResponse(BaseModel):
    id: uuid.UUID
    code: str
    name: str
    region: str

    model_config = {
        "from_attributes": True
    }


class MusclePriorityItem(BaseModel):
    muscle_code: str
    priority: PriorityType


class MusclePriorityUpdate(BaseModel):
    priorities: list[MusclePriorityItem]


class MusclePriorityResponse(BaseModel):
    muscle_code: str
    muscle_name: str
    priority: str