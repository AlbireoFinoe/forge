import uuid

import jwt
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_refresh_token_subject,
)
from app.schemas.auth import (
    RefreshTokenRequest,
    TokenResponse,
    UserLogin,
    UserRegister,
    UserResponse,
)
from app.models.user import User
from app.services.auth import (
    authenticate_user,
    create_user,
    get_user_by_email,
)


router = APIRouter(
    prefix="/auth",
    tags=["Authentication"],
)


@router.post(
    "/register",
    response_model=UserResponse,
    status_code=status.HTTP_201_CREATED,
)
def register(
    payload: UserRegister,
    db: Session = Depends(get_db),
):
    existing_user = get_user_by_email(
        db,
        payload.email,
    )

    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email already registered",
        )

    return create_user(
        db,
        payload.email,
        payload.password,
    )


@router.post(
    "/login",
    response_model=TokenResponse,
)
def login(
    payload: UserLogin,
    db: Session = Depends(get_db),
):
    user = authenticate_user(
        db,
        payload.email,
        payload.password,
    )

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    subject = str(user.id)

    access_token = create_access_token(
        subject
    )

    refresh_token = create_refresh_token(
        subject
    )

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
    )


@router.post(
    "/refresh",
    response_model=TokenResponse,
)
def refresh_access_token(
    payload: RefreshTokenRequest,
    db: Session = Depends(get_db),
):
    authentication_error = HTTPException(
        status_code=(
            status.HTTP_401_UNAUTHORIZED
        ),
        detail="Invalid or expired refresh token",
    )

    try:
        subject = (
            decode_refresh_token_subject(
                payload.refresh_token
            )
        )

        user_id = uuid.UUID(subject)

    except (
        jwt.InvalidTokenError,
        ValueError,
    ):
        raise authentication_error

    user = db.get(
        User,
        user_id,
    )

    if (
        user is None
        or not user.is_active
    ):
        raise authentication_error

    subject = str(user.id)

    return TokenResponse(
        access_token=create_access_token(
            subject
        ),
        refresh_token=create_refresh_token(
            subject
        ),
    )