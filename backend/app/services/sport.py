import uuid

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.sport_activity import SportActivity
from app.models.training_preference import TrainingPreference
from app.models.user import User
from app.schemas.sport import (
    SportActivityCreate,
    SportActivityUpdate,
)


def get_user_sports(
    db: Session,
    user: User,
) -> list[SportActivity]:
    statement = (
        select(SportActivity)
        .where(
            SportActivity.user_id == user.id
        )
        .order_by(
            SportActivity.day_of_week,
            SportActivity.sport_type,
        )
    )

    return list(
        db.scalars(statement).all()
    )


def get_user_sport_by_id(
    db: Session,
    user: User,
    sport_id: uuid.UUID,
) -> SportActivity | None:
    statement = select(
        SportActivity
    ).where(
        SportActivity.id == sport_id,
        SportActivity.user_id == user.id,
    )

    return db.scalar(statement)


def create_sport(
    db: Session,
    user: User,
    payload: SportActivityCreate,
) -> SportActivity:
    sport = SportActivity(
        user_id=user.id,
        sport_type=payload.sport_type.lower(),
        day_of_week=payload.day_of_week,
        duration_minutes=payload.duration_minutes,
        intensity=payload.intensity,
    )

    db.add(sport)
    db.commit()
    db.refresh(sport)

    return sport


def update_sport(
    db: Session,
    sport: SportActivity,
    payload: SportActivityUpdate,
) -> SportActivity:
    update_data = payload.model_dump(
        exclude_unset=True
    )

    if "sport_type" in update_data:
        update_data["sport_type"] = (
            update_data["sport_type"].lower()
        )

    for field, value in update_data.items():
        setattr(
            sport,
            field,
            value,
        )

    db.add(sport)
    db.commit()
    db.refresh(sport)

    return sport


def delete_sport(
    db: Session,
    sport: SportActivity,
) -> None:
    db.delete(sport)
    db.commit()


def set_sports_configured(
    db: Session,
    user: User,
    configured: bool,
) -> bool:
    statement = select(
        TrainingPreference
    ).where(
        TrainingPreference.user_id == user.id
    )

    preferences = db.scalar(statement)

    if preferences is None:
        raise ValueError(
            "Training preferences are missing"
        )

    preferences.sports_configured = configured

    db.add(preferences)
    db.commit()
    db.refresh(preferences)

    return preferences.sports_configured