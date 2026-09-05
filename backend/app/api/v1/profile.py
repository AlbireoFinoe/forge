from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.schemas.profile import (
    ProfileResponse,
    ProfileUpdate,
)
from app.services.profile import (
    get_or_create_profile,
    update_profile,
)


router = APIRouter(
    prefix="/profile",
    tags=["Profile"],
)


@router.get(
    "",
    response_model=ProfileResponse,
)
def get_profile(
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(get_db),
):
    return get_or_create_profile(
        db,
        current_user,
    )


@router.patch(
    "",
    response_model=ProfileResponse,
)
def patch_profile(
    payload: ProfileUpdate,
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(get_db),
):
    profile = get_or_create_profile(
        db,
        current_user,
    )

    return update_profile(
        db,
        profile,
        payload,
    )