from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.schemas.muscle_priority import (
    MuscleGroupResponse,
    MusclePriorityResponse,
    MusclePriorityUpdate,
)
from app.services.muscle_priority import (
    get_muscle_groups,
    get_user_muscle_priorities,
    set_muscle_priorities,
)


router = APIRouter(
    prefix="/muscles",
    tags=["Muscles"],
)


@router.get(
    "",
    response_model=list[MuscleGroupResponse],
)
def list_muscles(
    db: Session = Depends(get_db),
):
    return get_muscle_groups(db)


@router.put(
    "/priorities",
    response_model=list[MusclePriorityResponse],
)
def update_priorities(
    payload: MusclePriorityUpdate,
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(get_db),
):
    try:
        set_muscle_priorities(
            db,
            current_user,
            payload,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=422,
            detail=str(exc),
        )

    rows = get_user_muscle_priorities(
        db,
        current_user,
    )

    return [
        MusclePriorityResponse(
            muscle_code=muscle.code,
            muscle_name=muscle.name,
            priority=priority.priority,
        )
        for priority, muscle in rows
    ]


@router.get(
    "/priorities",
    response_model=list[MusclePriorityResponse],
)
def get_priorities(
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(get_db),
):
    rows = get_user_muscle_priorities(
        db,
        current_user,
    )

    return [
        MusclePriorityResponse(
            muscle_code=muscle.code,
            muscle_name=muscle.name,
            priority=priority.priority,
        )
        for priority, muscle in rows
    ]