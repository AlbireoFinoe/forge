from fastapi import FastAPI, HTTPException
from sqlalchemy import text

from app.core.database import engine


app = FastAPI(
    title="FORGE API",
    description="Backend API for FORGE Adaptive Training Planner",
    version="0.1.0",
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