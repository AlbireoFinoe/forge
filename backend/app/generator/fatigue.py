from app.generator.context import GeneratorContext


SAME_DAY_SPORT_FACTOR = {
    "low": 0.95,
    "moderate": 0.85,
    "high": 0.75,
}


COMBAT_SPORTS = {
    "boxing",
    "muay_thai",
    "kickboxing",
    "mma",
    "martial_arts",
}


def training_capacity_factor(
    context: GeneratorContext,
    day_of_week: int,
) -> float:

    day_sports = [
        sport
        for sport in context.sports
        if sport.day_of_week
        == day_of_week
    ]

    if not day_sports:
        return 1.0

    factor = 1.0

    for sport in day_sports:
        sport_factor = (
            SAME_DAY_SPORT_FACTOR.get(
                sport.intensity,
                0.9,
            )
        )

        if (
            sport.sport_type.lower()
            in COMBAT_SPORTS
        ):
            sport_factor -= 0.05

        factor = min(
            factor,
            sport_factor,
        )

    return max(
        factor,
        0.65,
    )