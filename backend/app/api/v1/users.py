from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.schemas.auth import UserResponse, UserUpdate


router = APIRouter(
    prefix="/users",
    tags=["Users"],
)


@router.get(
    "/me",
    response_model=UserResponse,
)
def get_me(
    current_user: User = Depends(
        get_current_user
    ),
):
    return current_user


@router.patch(
    "/me",
    response_model=UserResponse,
)
def update_me(
    payload: UserUpdate,
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(get_db),
):
    current_user.full_name = payload.full_name

    db.add(current_user)
    db.commit()
    db.refresh(current_user)

    return current_user
