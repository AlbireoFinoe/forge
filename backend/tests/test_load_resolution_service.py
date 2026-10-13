from decimal import Decimal

from app.services.load_resolution_service import (
    resolve_achievable_load,
)


def test_increase_rounds_up_to_increment():
    result = resolve_achievable_load(
        latest_weight_kg=Decimal("15"),
        suggested_load_change_percent=2.5,
        increment_kg=Decimal("1"),
    )

    assert result is not None
    assert (
        result.raw_weight_kg
        == Decimal("15.375")
    )
    assert (
        result.achievable_weight_kg
        == Decimal("16")
    )


def test_decrease_rounds_down_to_increment():
    result = resolve_achievable_load(
        latest_weight_kg=Decimal("15"),
        suggested_load_change_percent=-5.0,
        increment_kg=Decimal("1"),
    )

    assert result is not None
    assert (
        result.raw_weight_kg
        == Decimal("14.25")
    )
    assert (
        result.achievable_weight_kg
        == Decimal("14")
    )


def test_exact_increment_remains_exact():
    result = resolve_achievable_load(
        latest_weight_kg=Decimal("80"),
        suggested_load_change_percent=2.5,
        increment_kg=Decimal("2"),
    )

    assert result is not None
    assert (
        result.raw_weight_kg
        == Decimal("82.000")
    )
    assert (
        result.achievable_weight_kg
        == Decimal("82")
    )


def test_fractional_increment_is_supported():
    result = resolve_achievable_load(
        latest_weight_kg=Decimal("20"),
        suggested_load_change_percent=2.5,
        increment_kg=Decimal("0.5"),
    )

    assert result is not None
    assert (
        result.raw_weight_kg
        == Decimal("20.500")
    )
    assert (
        result.achievable_weight_kg
        == Decimal("20.5")
    )


def test_missing_latest_weight_is_unresolved():
    result = resolve_achievable_load(
        latest_weight_kg=None,
        suggested_load_change_percent=2.5,
        increment_kg=Decimal("1"),
    )

    assert result is None


def test_missing_increment_is_unresolved():
    result = resolve_achievable_load(
        latest_weight_kg=Decimal("15"),
        suggested_load_change_percent=2.5,
        increment_kg=None,
    )

    assert result is None


def test_zero_percentage_is_unresolved():
    result = resolve_achievable_load(
        latest_weight_kg=Decimal("15"),
        suggested_load_change_percent=0,
        increment_kg=Decimal("1"),
    )

    assert result is None
