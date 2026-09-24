from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.models.equipment import Equipment
from app.models.user import User
from app.models.user_equipment import UserEquipment
from app.models.user_load_preference import UserLoadPreference
from app.schemas.equipment import (
    UserEquipmentUpdate,
    UserLoadPreferenceUpdate,
)
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


LOAD_BEARING_EQUIPMENT_CODES = frozenset(
    {
        "BARBELL",
        "DUMBBELL",
        "CABLE",
        "MACHINE",
        "SMITH_MACHINE",
    }
)


def _validate_load_preference_codes(
    codes: list[str],
    catalog_codes: set[str],
) -> None:
    requested_codes = {
        code.upper()
        for code in codes
    }

    unknown_codes = sorted(
        requested_codes - catalog_codes
    )

    if unknown_codes:
        raise ValueError(
            "Unknown equipment codes: "
            + ", ".join(unknown_codes)
        )

    unsupported_codes = sorted(
        requested_codes
        - LOAD_BEARING_EQUIPMENT_CODES
    )

    if unsupported_codes:
        raise ValueError(
            "Load increments are not supported for: "
            + ", ".join(unsupported_codes)
        )


def get_user_load_preferences(
    db: Session,
    user: User,
) -> list[
    tuple[
        UserLoadPreference,
        Equipment,
    ]
]:
    statement = (
        select(
            UserLoadPreference,
            Equipment,
        )
        .join(
            Equipment,
            UserLoadPreference.equipment_id
            == Equipment.id,
        )
        .where(
            UserLoadPreference.user_id
            == user.id
        )
        .order_by(
            Equipment.name
        )
    )

    return list(
        db.execute(statement).all()
    )


def set_user_load_preferences(
    db: Session,
    user: User,
    payload: UserLoadPreferenceUpdate,
) -> list[
    tuple[
        UserLoadPreference,
        Equipment,
    ]
]:
    catalog = list(
        db.scalars(
            select(Equipment)
        ).all()
    )

    catalog_map = {
        equipment.code.upper(): equipment
        for equipment in catalog
    }

    codes = [
        item.equipment_code.upper()
        for item in payload.preferences
    ]

    _validate_load_preference_codes(
        codes,
        set(catalog_map),
    )

    db.execute(
        delete(
            UserLoadPreference
        ).where(
            UserLoadPreference.user_id
            == user.id
        )
    )

    for item in payload.preferences:
        equipment_code = (
            item.equipment_code.upper()
        )

        db.add(
            UserLoadPreference(
                user_id=user.id,
                equipment_id=(
                    catalog_map[
                        equipment_code
                    ].id
                ),
                increment_kg=(
                    item.increment_kg
                ),
            )
        )

    db.commit()

    return get_user_load_preferences(
        db,
        user,
    )
