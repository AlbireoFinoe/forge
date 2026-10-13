from sqlalchemy import create_engine
from sqlalchemy.engine import URL, make_url
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from app.core.config import settings


def get_database_url(*, unpooled: bool = False) -> URL:
    url = make_url(
        settings.database_url_unpooled
        if unpooled and settings.database_url_unpooled
        else settings.database_url
    )
    if url.drivername in ("postgres", "postgresql"):
        url = url.set(drivername="postgresql+psycopg")
    return url


engine = create_engine(
    get_database_url(),
    pool_pre_ping=True,
)


SessionLocal = sessionmaker(
    bind=engine,
    autoflush=False,
    autocommit=False,
)


class Base(DeclarativeBase):
    pass


def get_db():
    db = SessionLocal()

    try:
        yield db
    finally:
        db.close()