from sqlalchemy import select

from app.core.database import SessionLocal
from app.models.muscle_group import MuscleGroup


MUSCLE_GROUPS = [
    ("CHEST", "Chest", "upper_body"),
    ("BACK", "Back", "upper_body"),

    ("FRONT_DELTS", "Front Delts", "upper_body"),
    ("SIDE_DELTS", "Side Delts", "upper_body"),
    ("REAR_DELTS", "Rear Delts", "upper_body"),

    ("BICEPS", "Biceps", "upper_body"),
    ("TRICEPS", "Triceps", "upper_body"),
    ("FOREARMS", "Forearms", "upper_body"),

    ("TRAPS", "Traps", "upper_body"),

    ("ABS", "Abs", "core"),

    ("QUADS", "Quads", "lower_body"),
    ("HAMSTRINGS", "Hamstrings", "lower_body"),
    ("GLUTES", "Glutes", "lower_body"),
    ("CALVES", "Calves", "lower_body"),
]


def seed_muscle_groups():
    db = SessionLocal()

    try:
        for code, name, region in MUSCLE_GROUPS:
            existing = db.scalar(
                select(MuscleGroup).where(
                    MuscleGroup.code == code
                )
            )

            if existing is None:
                db.add(
                    MuscleGroup(
                        code=code,
                        name=name,
                        region=region,
                    )
                )

        db.commit()

    finally:
        db.close()


if __name__ == "__main__":
    seed_muscle_groups()