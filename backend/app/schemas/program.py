from datetime import datetime
from uuid import UUID

from pydantic import BaseModel


class ProgramWarningResponse(BaseModel):
    code: str
    message: str


class ProgramGenerateResponse(BaseModel):
    id: UUID
    name: str

    version_number: int
    generator_version: str

    goal: str
    status: str

    validation_passed: bool

    program_days: int
    program_exercises: int

    warnings: list[
        ProgramWarningResponse
    ]

    created_at: datetime