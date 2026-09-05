from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.user import User
from app.models.user_profile import UserProfile
from app.schemas.profile import ProfileUpdate


def get_profile_by_user(
    db: Session,
    user: User,
) -> UserProfile | None:
    statement = select(UserProfile).where(
        UserProfile.user_id == user.id
    )

    return db.scalar(statement)


def create_empty_profile(
    db: Session,
    user: User,
) -> UserProfile:
    profile = UserProfile(
        user_id=user.id,
    )

    db.add(profile)
    db.commit()
    db.refresh(profile)

    return profile


def get_or_create_profile(
    db: Session,
    user: User,
) -> UserProfile:
    profile = get_profile_by_user(
        db,
        user,
    )

    if profile is not None:
        return profile

    return create_empty_profile(
        db,
        user,
    )


def update_profile(
    db: Session,
    profile: UserProfile,
    payload: ProfileUpdate,
) -> UserProfile:
    update_data = payload.model_dump(
        exclude_unset=True
    )

    for field, value in update_data.items():
        setattr(
            profile,
            field,
            value,
        )

    db.add(profile)
    db.commit()
    db.refresh(profile)

    return profile