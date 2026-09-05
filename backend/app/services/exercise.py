import uuid

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.equipment import Equipment
from app.models.exercise import Exercise
from app.models.exercise_equipment import ExerciseEquipment
from app.models.exercise_secondary_muscle import (
    ExerciseSecondaryMuscle,
)
from app.models.muscle_group import MuscleGroup


def get_exercises(
    db: Session,
    muscle: str | None = None,
    equipment: str | None = None,
    difficulty: str | None = None,
    compound: bool | None = None,
    search: str | None = None,
) -> list[tuple[Exercise, MuscleGroup]]:
    statement = (
        select(
            Exercise,
            MuscleGroup,
        )
        .join(
            MuscleGroup,
            Exercise.primary_muscle_id
            == MuscleGroup.id,
        )
        .where(
            Exercise.active.is_(True)
        )
    )

    if muscle:
        statement = statement.where(
            MuscleGroup.code == muscle.upper()
        )

    if difficulty:
        statement = statement.where(
            Exercise.difficulty
            == difficulty.lower()
        )

    if compound is not None:
        statement = statement.where(
            Exercise.is_compound == compound
        )

    if search:
        statement = statement.where(
            Exercise.name.ilike(
                f"%{search}%"
            )
        )

    if equipment:
        statement = (
            statement
            .join(
                ExerciseEquipment,
                ExerciseEquipment.exercise_id
                == Exercise.id,
            )
            .join(
                Equipment,
                ExerciseEquipment.equipment_id
                == Equipment.id,
            )
            .where(
                Equipment.code
                == equipment.upper()
            )
        )

    statement = (
        statement
        .distinct()
        .order_by(
            MuscleGroup.name,
            Exercise.name,
        )
    )

    return list(
        db.execute(statement).all()
    )


def get_exercise_by_id(
    db: Session,
    exercise_id: uuid.UUID,
) -> tuple[Exercise, MuscleGroup] | None:
    statement = (
        select(
            Exercise,
            MuscleGroup,
        )
        .join(
            MuscleGroup,
            Exercise.primary_muscle_id
            == MuscleGroup.id,
        )
        .where(
            Exercise.id == exercise_id,
            Exercise.active.is_(True),
        )
    )

    return db.execute(
        statement
    ).first()


def get_exercise_equipment(
    db: Session,
    exercise: Exercise,
) -> list[Equipment]:
    statement = (
        select(Equipment)
        .join(
            ExerciseEquipment,
            ExerciseEquipment.equipment_id
            == Equipment.id,
        )
        .where(
            ExerciseEquipment.exercise_id
            == exercise.id
        )
        .order_by(
            Equipment.name
        )
    )

    return list(
        db.scalars(statement).all()
    )


def get_exercise_secondary_muscles(
    db: Session,
    exercise: Exercise,
):
    statement = (
        select(
            ExerciseSecondaryMuscle,
            MuscleGroup,
        )
        .join(
            MuscleGroup,
            ExerciseSecondaryMuscle.muscle_group_id
            == MuscleGroup.id,
        )
        .where(
            ExerciseSecondaryMuscle.exercise_id
            == exercise.id
        )
        .order_by(
            MuscleGroup.name
        )
    )

    return db.execute(
        statement
    ).all()