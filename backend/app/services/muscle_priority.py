from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.models.muscle_group import MuscleGroup
from app.models.user import User
from app.models.user_muscle_priority import UserMusclePriority
from app.schemas.muscle_priority import MusclePriorityUpdate
from app.services.training_setup_revision import (
    bump_training_setup_revision,
)


def get_muscle_groups(
    db: Session,
) -> list[MuscleGroup]:
    statement = (
        select(MuscleGroup)
        .order_by(
            MuscleGroup.region,
            MuscleGroup.name,
        )
    )

    return list(
        db.scalars(statement).all()
    )


def set_muscle_priorities(
    db: Session,
    user: User,
    payload: MusclePriorityUpdate,
) -> None:
    codes = [
        item.muscle_code.upper()
        for item in payload.priorities
    ]

    if len(codes) != len(set(codes)):
        raise ValueError(
            "Duplicate muscle groups are not allowed"
        )

    statement = select(MuscleGroup).where(
        MuscleGroup.code.in_(codes)
    )

    muscles = list(
        db.scalars(statement).all()
    )

    muscle_map = {
        muscle.code: muscle
        for muscle in muscles
    }

    if len(muscle_map) != len(codes):
        raise ValueError(
            "One or more muscle groups are invalid"
        )

    requested_priorities = {
        item.muscle_code.upper(): item.priority
        for item in payload.priorities
    }

    existing_rows = (
        get_user_muscle_priorities(
            db,
            user,
        )
    )

    existing_priorities = {
        muscle.code: user_priority.priority
        for user_priority, muscle
        in existing_rows
    }

    if existing_priorities == requested_priorities:
        return

    db.execute(
        delete(UserMusclePriority).where(
            UserMusclePriority.user_id == user.id
        )
    )

    for code, priority in requested_priorities.items():
        muscle = muscle_map[code]

        db.add(
            UserMusclePriority(
                user_id=user.id,
                muscle_group_id=muscle.id,
                priority=priority,
            )
        )

    bump_training_setup_revision(
        user
    )

    db.commit()


def get_user_muscle_priorities(
    db: Session,
    user: User,
):
    statement = (
        select(
            UserMusclePriority,
            MuscleGroup,
        )
        .join(
            MuscleGroup,
            UserMusclePriority.muscle_group_id
            == MuscleGroup.id,
        )
        .where(
            UserMusclePriority.user_id == user.id
        )
        .order_by(
            MuscleGroup.name
        )
    )

    return db.execute(statement).all()