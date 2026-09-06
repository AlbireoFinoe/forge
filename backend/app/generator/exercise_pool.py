import uuid
from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.generator.context import GeneratorContext
from app.models.equipment import Equipment
from app.models.exercise import Exercise
from app.models.exercise_equipment import ExerciseEquipment
from app.models.exercise_secondary_muscle import (
    ExerciseSecondaryMuscle,
)
from app.models.muscle_group import MuscleGroup


@dataclass(frozen=True)
class SecondaryMuscleContribution:
    muscle_code: str
    weight: float


@dataclass(frozen=True)
class ExerciseCandidate:
    id: uuid.UUID

    code: str
    name: str

    primary_muscle: str
    secondary_muscles: tuple[
        SecondaryMuscleContribution,
        ...
    ]

    movement_pattern: str
    difficulty: str
    is_compound: bool

    min_reps: int
    max_reps: int
    rest_seconds: int

    required_equipment: frozenset[str]

    def contribution_for(
        self,
        muscle_code: str,
    ) -> float:

        if self.primary_muscle == muscle_code:
            return 1.0

        for secondary in self.secondary_muscles:
            if (
                secondary.muscle_code
                == muscle_code
            ):
                return secondary.weight

        return 0.0


def load_exercise_pool(
    db: Session,
    context: GeneratorContext,
) -> tuple[ExerciseCandidate, ...]:

    exercise_rows = db.execute(
        select(
            Exercise,
            MuscleGroup.code,
        )
        .join(
            MuscleGroup,
            Exercise.primary_muscle_id
            == MuscleGroup.id,
        )
        .where(
            Exercise.active.is_(True)
        )
        .order_by(
            Exercise.name
        )
    ).all()

    if not exercise_rows:
        return ()

    exercise_ids = [
        exercise.id
        for exercise, _ in exercise_rows
    ]

    equipment_rows = db.execute(
        select(
            ExerciseEquipment.exercise_id,
            Equipment.code,
        )
        .join(
            Equipment,
            ExerciseEquipment.equipment_id
            == Equipment.id,
        )
        .where(
            ExerciseEquipment.exercise_id.in_(
                exercise_ids
            )
        )
    ).all()

    equipment_map: dict[
        uuid.UUID,
        set[str],
    ] = {}

    for (
        exercise_id,
        equipment_code,
    ) in equipment_rows:

        equipment_map.setdefault(
            exercise_id,
            set(),
        ).add(
            equipment_code
        )

    secondary_rows = db.execute(
        select(
            ExerciseSecondaryMuscle.exercise_id,
            MuscleGroup.code,
            ExerciseSecondaryMuscle.contribution_weight,
        )
        .join(
            MuscleGroup,
            ExerciseSecondaryMuscle.muscle_group_id
            == MuscleGroup.id,
        )
        .where(
            ExerciseSecondaryMuscle.exercise_id.in_(
                exercise_ids
            )
        )
    ).all()

    secondary_map: dict[
        uuid.UUID,
        list[SecondaryMuscleContribution],
    ] = {}

    for (
        exercise_id,
        muscle_code,
        weight,
    ) in secondary_rows:

        secondary_map.setdefault(
            exercise_id,
            [],
        ).append(
            SecondaryMuscleContribution(
                muscle_code=muscle_code,
                weight=float(weight),
            )
        )

    candidates = []

    for (
        exercise,
        primary_muscle,
    ) in exercise_rows:

        required_equipment = frozenset(
            equipment_map.get(
                exercise.id,
                set(),
            )
        )

        # All required equipment must exist.
        if not required_equipment.issubset(
            context.available_equipment
        ):
            continue

        secondary_muscles = tuple(
            sorted(
                secondary_map.get(
                    exercise.id,
                    [],
                ),
                key=lambda item: (
                    item.muscle_code
                ),
            )
        )

        candidates.append(
            ExerciseCandidate(
                id=exercise.id,
                code=exercise.code,
                name=exercise.name,
                primary_muscle=primary_muscle,
                secondary_muscles=(
                    secondary_muscles
                ),
                movement_pattern=(
                    exercise.movement_pattern
                ),
                difficulty=(
                    exercise.difficulty
                ),
                is_compound=(
                    exercise.is_compound
                ),
                min_reps=(
                    exercise.default_min_reps
                ),
                max_reps=(
                    exercise.default_max_reps
                ),
                rest_seconds=(
                    exercise.default_rest_seconds
                ),
                required_equipment=(
                    required_equipment
                ),
            )
        )

    return tuple(
        candidates
    )


def get_candidates_for_muscle(
    pool: tuple[
        ExerciseCandidate,
        ...
    ],
    muscle_code: str,
) -> tuple[
    ExerciseCandidate,
    ...
]:
    return tuple(
        exercise
        for exercise in pool
        if exercise.contribution_for(
            muscle_code
        ) > 0
    )