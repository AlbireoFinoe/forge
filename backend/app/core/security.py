from datetime import datetime, timedelta, timezone

import jwt
from pwdlib import PasswordHash

from app.core.config import settings


password_hasher = PasswordHash.recommended()

ACCESS_TOKEN_TYPE = "access"
REFRESH_TOKEN_TYPE = "refresh"


def hash_password(password: str) -> str:
    return password_hasher.hash(password)


def verify_password(
    plain_password: str,
    hashed_password: str,
) -> bool:
    return password_hasher.verify(
        plain_password,
        hashed_password,
    )


def _create_token(
    subject: str,
    token_type: str,
    expires_delta: timedelta,
) -> str:
    issued_at = datetime.now(timezone.utc)

    payload = {
        "sub": subject,
        "token_type": token_type,
        "iat": issued_at,
        "exp": issued_at + expires_delta,
    }

    return jwt.encode(
        payload,
        settings.jwt_secret_key,
        algorithm=settings.jwt_algorithm,
    )


def create_access_token(
    subject: str,
) -> str:
    return _create_token(
        subject=subject,
        token_type=ACCESS_TOKEN_TYPE,
        expires_delta=timedelta(
            minutes=(
                settings
                .jwt_access_token_expire_minutes
            )
        ),
    )


def create_refresh_token(
    subject: str,
) -> str:
    return _create_token(
        subject=subject,
        token_type=REFRESH_TOKEN_TYPE,
        expires_delta=timedelta(
            days=(
                settings
                .jwt_refresh_token_expire_days
            )
        ),
    )


def _decode_token_subject(
    token: str,
    expected_type: str,
) -> str:
    payload = jwt.decode(
        token,
        settings.jwt_secret_key,
        algorithms=[
            settings.jwt_algorithm
        ],
    )

    token_type = payload.get(
        "token_type"
    )

    if token_type != expected_type:
        raise jwt.InvalidTokenError(
            "Invalid token type"
        )

    subject = payload.get("sub")

    if (
        not isinstance(subject, str)
        or not subject
    ):
        raise jwt.InvalidTokenError(
            "Invalid token subject"
        )

    return subject


def decode_access_token_subject(
    token: str,
) -> str:
    return _decode_token_subject(
        token,
        ACCESS_TOKEN_TYPE,
    )


def decode_refresh_token_subject(
    token: str,
) -> str:
    return _decode_token_subject(
        token,
        REFRESH_TOKEN_TYPE,
    )