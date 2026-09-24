import uuid
from decimal import Decimal

from pydantic import BaseModel, Field, model_validator


class EquipmentResponse(BaseModel):
    id: uuid.UUID
    code: str
    name: str

    model_config = {
        "from_attributes": True
    }


class UserEquipmentUpdate(BaseModel):
    equipment_codes: list[str] = Field(
        min_length=1,
    )

    @model_validator(mode="after")
    def validate_equipment_codes(self):
        normalized = [
            code.upper()
            for code in self.equipment_codes
        ]

        if len(normalized) != len(set(normalized)):
            raise ValueError(
                "equipment_codes cannot contain duplicates"
            )

        if "FULL_GYM" in normalized and len(normalized) > 1:
            raise ValueError(
                "FULL_GYM cannot be combined with other equipment"
            )

        return self


class UserEquipmentResponse(BaseModel):
    equipment: list[EquipmentResponse]


class UserLoadPreferenceItemUpdate(BaseModel):
    equipment_code: str = Field(
        min_length=1,
    )
    increment_kg: Decimal = Field(
        gt=0,
    )


class UserLoadPreferenceUpdate(BaseModel):
    preferences: list[
        UserLoadPreferenceItemUpdate
    ]

    @model_validator(mode="after")
    def validate_unique_equipment_codes(self):
        normalized = [
            item.equipment_code.upper()
            for item in self.preferences
        ]

        if len(normalized) != len(set(normalized)):
            raise ValueError(
                "equipment_code cannot contain duplicates"
            )

        return self


class UserLoadPreferenceItemResponse(BaseModel):
    equipment_code: str
    equipment_name: str
    increment_kg: Decimal


class UserLoadPreferenceResponse(BaseModel):
    preferences: list[
        UserLoadPreferenceItemResponse
    ]
