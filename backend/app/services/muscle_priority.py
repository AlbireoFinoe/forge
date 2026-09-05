from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.models.muscle_group import MuscleGroup
from app.models.user import User
from app.models.user_muscle_priority import UserMusclePriority
from app.schemas.muscle_priority import MusclePriorityUpdate


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
    db.execute(
        delete(UserMusclePriority).where(
            UserMusclePriority.user_id == user.id
        )
    )

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

    for item in payload.priorities:
        muscle = muscle_map[
            item.muscle_code.upper()
        ]

        db.add(
            UserMusclePriority(
                user_id=user.id,
                muscle_group_id=muscle.id,
                priority=item.priority,
            )
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