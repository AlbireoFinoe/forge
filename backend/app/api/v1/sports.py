import uuid

from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    Response,
    status,
)
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.schemas.sport import (
    SportActivityCreate,
    SportActivityResponse,
    SportActivityUpdate,
    SportsSetupResponse,
    SportsSetupUpdate,
)
from app.services.sport import (
    create_sport,
    delete_sport,
    get_user_sport_by_id,
    get_user_sports,
    set_sports_configured,
    update_sport,
)


router = APIRouter(
    prefix="/sports",
    tags=["Sports"],
)


@router.get(
    "",
    response_model=list[SportActivityResponse],
)
def list_sports(
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(get_db),
):
    return get_user_sports(
        db,
        current_user,
    )


@router.post(
    "",
    response_model=SportActivityResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_sport_activity(
    payload: SportActivityCreate,
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(get_db),
):
    return create_sport(
        db,
        current_user,
        payload,
    )


@router.put(
    "/setup",
    response_model=SportsSetupResponse,
)
def update_sports_setup(
    payload: SportsSetupUpdate,
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(get_db),
):
    try:
        configured = set_sports_configured(
            db,
            current_user,
            payload.configured,
        )

    except ValueError as exc:
        raise HTTPException(
            status_code=422,
            detail=str(exc),
        )

    return SportsSetupResponse(
        configured=configured
    )


@router.patch(
    "/{sport_id}",
    response_model=SportActivityResponse,
)
def patch_sport_activity(
    sport_id: uuid.UUID,
    payload: SportActivityUpdate,
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(get_db),
):
    sport = get_user_sport_by_id(
        db,
        current_user,
        sport_id,
    )

    if sport is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Sport activity not found",
        )

    return update_sport(
        db,
        current_user,
        sport,
        payload,
    )


@router.delete(
    "/{sport_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_sport_activity(
    sport_id: uuid.UUID,
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(get_db),
):
    sport = get_user_sport_by_id(
        db,
        current_user,
        sport_id,
    )

    if sport is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Sport activity not found",
        )

    delete_sport(
        db,
        current_user,
        sport,
    )

    return Response(
        status_code=status.HTTP_204_NO_CONTENT
    )