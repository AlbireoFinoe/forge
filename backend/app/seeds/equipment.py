from sqlalchemy import select

from app.core.database import SessionLocal
from app.models.equipment import Equipment


EQUIPMENT = [
    ("FULL_GYM", "Full Gym"),
    ("BARBELL", "Barbell"),
    ("DUMBBELL", "Dumbbell"),
    ("CABLE", "Cable"),
    ("MACHINE", "Machine"),
    ("SMITH_MACHINE", "Smith Machine"),
    ("BENCH", "Bench"),
    ("PULLUP_BAR", "Pull-Up Bar"),
    ("BODYWEIGHT", "Bodyweight"),
]


def seed_equipment():
    db = SessionLocal()

    try:
        for code, name in EQUIPMENT:
            existing = db.scalar(
                select(Equipment).where(
                    Equipment.code == code
                )
            )

            if existing is None:
                db.add(
                    Equipment(
                        code=code,
                        name=name,
                    )
                )

        db.commit()

    finally:
        db.close()


if __name__ == "__main__":
    seed_equipment()