from decimal import Decimal

import pytest
from fastapi.routing import APIRoute
from pydantic import ValidationError

from app.main import app
from app.schemas.equipment import (
    UserLoadPreferenceItemUpdate,
    UserLoadPreferenceUpdate,
)
from app.services.equipment import (
    _validate_load_preference_codes,
)


def test_load_preference_schema_accepts_load_bearing_equipment():
    payload = UserLoadPreferenceUpdate(
        preferences=[
            UserLoadPreferenceItemUpdate(
                equipment_code="DUMBBELL",
                increment_kg=Decimal("1.0"),
            )
        ]
    )

    assert len(payload.preferences) == 1
    assert (
        payload.preferences[0].increment_kg
        == Decimal("1.0")
    )


def test_load_preference_schema_rejects_duplicate_equipment_codes():
    with pytest.raises(
        ValidationError
    ):
        UserLoadPreferenceUpdate(
            preferences=[
                UserLoadPreferenceItemUpdate(
                    equipment_code="DUMBBELL",
                    increment_kg=Decimal("1"),
                ),
                UserLoadPreferenceItemUpdate(
                    equipment_code="dumbbell",
                    increment_kg=Decimal("2"),
                ),
            ]
        )


def test_load_preference_schema_rejects_non_positive_increment():
    with pytest.raises(
        ValidationError
    ):
        UserLoadPreferenceItemUpdate(
            equipment_code="DUMBBELL",
            increment_kg=Decimal("0"),
        )


def test_load_preference_validator_accepts_supported_equipment():
    _validate_load_preference_codes(
        [
            "DUMBBELL",
            "BARBELL",
            "MACHINE",
        ],
        {
            "DUMBBELL",
            "BARBELL",
            "MACHINE",
            "BODYWEIGHT",
        },
    )


def test_load_preference_validator_rejects_non_load_bearing_equipment():
    with pytest.raises(
        ValueError,
        match="BODYWEIGHT",
    ):
        _validate_load_preference_codes(
            ["BODYWEIGHT"],
            {
                "BODYWEIGHT",
                "DUMBBELL",
            },
        )


def test_load_preference_validator_rejects_unknown_equipment():
    with pytest.raises(
        ValueError,
        match="UNKNOWN",
    ):
        _validate_load_preference_codes(
            ["UNKNOWN"],
            {
                "DUMBBELL",
                "BARBELL",
            },
        )


def test_load_preference_routes_are_registered():
    paths = app.openapi()["paths"]

    route = paths[
        "/api/v1/equipment/load-preferences"
    ]

    assert "get" in route
    assert "put" in route
