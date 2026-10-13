from dataclasses import dataclass
from decimal import Decimal, ROUND_CEILING, ROUND_FLOOR


@dataclass(frozen=True)
class LoadResolution:
    raw_weight_kg: Decimal
    achievable_weight_kg: Decimal


def _to_decimal(value: Decimal | int | float) -> Decimal:
    if isinstance(value, Decimal):
        return value

    return Decimal(str(value))


def resolve_achievable_load(
    latest_weight_kg: Decimal | int | float | None,
    suggested_load_change_percent: Decimal | int | float | None,
    increment_kg: Decimal | int | float | None,
) -> LoadResolution | None:
    """
    Resolve a raw adaptation load into a weight achievable with the
    user's configured equipment increment.
    """

    if (
        latest_weight_kg is None
        or suggested_load_change_percent is None
        or increment_kg is None
    ):
        return None

    latest_weight = _to_decimal(latest_weight_kg)
    percentage = _to_decimal(suggested_load_change_percent)
    increment = _to_decimal(increment_kg)

    if increment <= 0 or percentage == 0:
        return None

    raw_weight = latest_weight * (
        Decimal("1") + percentage / Decimal("100")
    )

    increment_steps = raw_weight / increment

    if percentage > 0:
        rounded_steps = increment_steps.to_integral_value(
            rounding=ROUND_CEILING
        )
    else:
        rounded_steps = increment_steps.to_integral_value(
            rounding=ROUND_FLOOR
        )

    achievable_weight = rounded_steps * increment

    return LoadResolution(
        raw_weight_kg=raw_weight,
        achievable_weight_kg=achievable_weight,
    )
