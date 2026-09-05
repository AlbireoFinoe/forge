import uuid

from pydantic import BaseModel, model_validator


class EquipmentResponse(BaseModel):
    id: uuid.UUID
    code: str
    name: str

    model_config = {
        "from_attributes": True
    }


class UserEquipmentUpdate(BaseModel):
    equipment_codes: list[str]

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