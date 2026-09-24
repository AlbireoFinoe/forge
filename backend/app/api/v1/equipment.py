from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.schemas.equipment import (
    EquipmentResponse,
    UserEquipmentResponse,
    UserEquipmentUpdate,
    UserLoadPreferenceItemResponse,
    UserLoadPreferenceResponse,
    UserLoadPreferenceUpdate,
)
from app.services.equipment import (
    get_all_equipment,
    get_user_equipment,
    set_user_equipment,
    get_user_load_preferences,
    set_user_load_preferences,
)


router = APIRouter(
    prefix="/equipment",
    tags=["Equipment"],
)


@router.get(
    "",
    response_model=list[EquipmentResponse],
)
def list_equipment(
    db: Session = Depends(get_db),
):
    return get_all_equipment(db)


@router.get(
    "/me",
    response_model=UserEquipmentResponse,
)
def get_my_equipment(
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(get_db),
):
    return UserEquipmentResponse(
        equipment=get_user_equipment(
            db,
            current_user,
        )
    )


@router.put(
    "/me",
    response_model=UserEquipmentResponse,
)
def update_my_equipment(
    payload: UserEquipmentUpdate,
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(get_db),
):
    try:
        equipment = set_user_equipment(
            db,
            current_user,
            payload,
        )

    except ValueError as exc:
        raise HTTPException(
            status_code=422,
            detail=str(exc),
        )

    return UserEquipmentResponse(
        equipment=equipment
    )


@router.get(
    "/load-preferences",
    response_model=UserLoadPreferenceResponse,
)
def get_my_load_preferences(
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(get_db),
):
    rows = get_user_load_preferences(
        db,
        current_user,
    )

    return UserLoadPreferenceResponse(
        preferences=[
            UserLoadPreferenceItemResponse(
                equipment_code=equipment.code,
                equipment_name=equipment.name,
                increment_kg=(
                    preference.increment_kg
                ),
            )
            for preference, equipment in rows
        ]
    )


@router.put(
    "/load-preferences",
    response_model=UserLoadPreferenceResponse,
)
def update_my_load_preferences(
    payload: UserLoadPreferenceUpdate,
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(get_db),
):
    try:
        rows = set_user_load_preferences(
            db=db,
            user=current_user,
            payload=payload,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=(
                status.HTTP_422_UNPROCESSABLE_ENTITY
            ),
            detail=str(exc),
        ) from exc

    return UserLoadPreferenceResponse(
        preferences=[
            UserLoadPreferenceItemResponse(
                equipment_code=equipment.code,
                equipment_name=equipment.name,
                increment_kg=(
                    preference.increment_kg
                ),
            )
            for preference, equipment in rows
        ]
    )
