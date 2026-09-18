from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.user import User
from app.models.user_profile import UserProfile
from app.schemas.profile import ProfileUpdate
from app.services.training_setup_revision import (
    bump_training_setup_revision,
)


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
    user: User,
    profile: UserProfile,
    payload: ProfileUpdate,
) -> UserProfile:
    update_data = payload.model_dump(
        exclude_unset=True
    )

    has_changes = any(
        getattr(profile, field) != value
        for field, value in update_data.items()
    )

    if not has_changes:
        return profile

    experience_changed = (
        "experience_level" in update_data
        and profile.experience_level
        != update_data["experience_level"]
    )

    for field, value in update_data.items():
        setattr(
            profile,
            field,
            value,
        )

    if experience_changed:
        bump_training_setup_revision(
            user
        )

    db.add(profile)
    db.commit()
    db.refresh(profile)

    return profile