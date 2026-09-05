from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.schemas.equipment import (
    EquipmentResponse,
    UserEquipmentResponse,
    UserEquipmentUpdate,
)
from app.services.equipment import (
    get_all_equipment,
    get_user_equipment,
    set_user_equipment,
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