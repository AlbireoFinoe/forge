import uuid

import jwt
from fastapi import Depends, HTTPException, Security, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import get_db
from app.models.user import User


bearer_scheme = HTTPBearer(
    auto_error=False
)


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Security(
        bearer_scheme
    ),
    db: Session = Depends(get_db),
) -> User:
    authentication_error = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={
            "WWW-Authenticate": "Bearer"
        },
    )

    if credentials is None:
        raise authentication_error

    token = credentials.credentials

    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret_key,
            algorithms=[
                settings.jwt_algorithm
            ],
        )

        subject = payload.get("sub")

        if subject is None:
            raise authentication_error

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

    if user is None:
        raise authentication_error

    if not user.is_active:
        raise authentication_error

    return user