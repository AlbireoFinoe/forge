from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import hash_password, verify_password
from app.models.user import User


def get_user_by_email(
    db: Session,
    email: str,
) -> User | None:
    statement = select(User).where(
        User.email == email.lower()
    )

    return db.scalar(statement)


def create_user(
    db: Session,
    full_name: str,
    email: str,
    password: str,
) -> User:
    user = User(
        full_name=full_name,
        email=email.lower(),
        password_hash=hash_password(password),
    )

    db.add(user)
    db.commit()
    db.refresh(user)

    return user


def authenticate_user(
    db: Session,
    email: str,
    password: str,
) -> User | None:
    user = get_user_by_email(
        db,
        email,
    )

    if user is None:
        return None

    if not verify_password(
        password,
        user.password_hash,
    ):
        return None

    if not user.is_active:
        return None

    return user