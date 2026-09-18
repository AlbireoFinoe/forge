from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.models.equipment import Equipment
from app.models.user import User
from app.models.user_equipment import UserEquipment
from app.schemas.equipment import UserEquipmentUpdate
from app.services.training_setup_revision import (
    bump_training_setup_revision,
)


def get_all_equipment(
    db: Session,
) -> list[Equipment]:
    statement = select(
        Equipment
    ).order_by(
        Equipment.name
    )

    return list(
        db.scalars(statement).all()
    )


def get_user_equipment(
    db: Session,
    user: User,
) -> list[Equipment]:
    statement = (
        select(Equipment)
        .join(
            UserEquipment,
            UserEquipment.equipment_id
            == Equipment.id,
        )
        .where(
            UserEquipment.user_id == user.id
        )
        .order_by(
            Equipment.name
        )
    )

    return list(
        db.scalars(statement).all()
    )


def set_user_equipment(
    db: Session,
    user: User,
    payload: UserEquipmentUpdate,
) -> list[Equipment]:
    codes = [
        code.upper()
        for code in payload.equipment_codes
    ]

    statement = select(
        Equipment
    ).where(
        Equipment.code.in_(codes)
    )

    equipment_items = list(
        db.scalars(statement).all()
    )

    equipment_map = {
        equipment.code: equipment
        for equipment in equipment_items
    }

    if len(equipment_map) != len(codes):
        raise ValueError(
            "One or more equipment codes are invalid"
        )

    existing_equipment = get_user_equipment(
        db,
        user,
    )

    existing_codes = {
        equipment.code
        for equipment
        in existing_equipment
    }

    requested_codes = set(codes)

    if existing_codes == requested_codes:
        return existing_equipment

    db.execute(
        delete(UserEquipment).where(
            UserEquipment.user_id == user.id
        )
    )

    for code in codes:
        equipment = equipment_map[code]

        db.add(
            UserEquipment(
                user_id=user.id,
                equipment_id=equipment.id,
            )
        )

    bump_training_setup_revision(
        user
    )

    db.commit()

    return get_user_equipment(
        db,
        user,
    )