from fastapi import FastAPI, HTTPException
from sqlalchemy import text
from app.api.v1.auth import router as auth_router
from app.api.v1.users import router as users_router
from app.core.database import engine
from app.api.v1.profile import router as profile_router
from app.api.v1.onboarding import router as onboarding_router


app = FastAPI(
    title="FORGE API",
    description="Backend API for FORGE Adaptive Training Planner",
    version="0.1.0",
)
app.include_router(
    auth_router,
    prefix="/api/v1",
)
app.include_router(
    users_router,
    prefix="/api/v1",
)
app.include_router(
    profile_router,
    prefix="/api/v1",
)
app.include_router(
    onboarding_router,
    prefix="/api/v1",
)


@app.get("/")
def root():
    return {
        "message": "Welcome to FORGE API"
    }


@app.get("/api/v1/health")
def health_check():
    return {
        "status": "ok",
        "service": "forge-api"
    }


@app.get("/api/v1/health/database")
def database_health_check():
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))

        return {
            "status": "ok",
            "database": "connected"
        }

    except Exception:
        raise HTTPException(
            status_code=503,
            detail="Database connection failed"
        )