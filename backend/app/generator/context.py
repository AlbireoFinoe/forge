import uuid
from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.equipment import Equipment
from app.models.goal import Goal
from app.models.muscle_group import MuscleGroup
from app.models.sport_activity import SportActivity
from app.models.training_day import TrainingDay
from app.models.training_preference import TrainingPreference
from app.models.user import User
from app.models.user_equipment import UserEquipment
from app.models.user_muscle_priority import UserMusclePriority
from app.models.user_profile import UserProfile


class GeneratorContextError(Exception):
    pass


@dataclass(frozen=True)
class SportContext:
    sport_type: str
    day_of_week: int
    duration_minutes: int
    intensity: str


@dataclass(frozen=True)
class GeneratorContext:
    user_id: uuid.UUID

    goal: str
    experience_level: str

    days_per_week: int
    available_days: tuple[int, ...]
    session_duration_minutes: int

    no_dedicated_leg_day: bool
    arm_specialization: bool

    muscle_priorities: dict[str, str]

    equipment_selection: tuple[str, ...]
    available_equipment: frozenset[str]

    sports: tuple[SportContext, ...]


def build_generator_context(
    db: Session,
    user: User,
) -> GeneratorContext:
    profile = db.scalar(
        select(UserProfile).where(
            UserProfile.user_id == user.id
        )
    )

    if profile is None:
        raise GeneratorContextError(
            "User profile is missing"
        )

    if not profile.experience_level:
        raise GeneratorContextError(
            "Experience level is missing"
        )

    goal = db.scalar(
        select(Goal).where(
            Goal.user_id == user.id
        )
    )

    if goal is None:
        raise GeneratorContextError(
            "Training goal is missing"
        )

    preference = db.scalar(
        select(TrainingPreference).where(
            TrainingPreference.user_id == user.id
        )
    )

    if preference is None:
        raise GeneratorContextError(
            "Training preferences are missing"
        )

    available_days = tuple(
        db.scalars(
            select(TrainingDay.day_of_week)
            .where(
                TrainingDay.user_id == user.id
            )
            .order_by(
                TrainingDay.day_of_week
            )
        ).all()
    )

    if len(available_days) != preference.days_per_week:
        raise GeneratorContextError(
            "Available training days do not match days_per_week"
        )

    all_muscle_codes = list(
        db.scalars(
            select(MuscleGroup.code)
            .order_by(MuscleGroup.code)
        ).all()
    )

    muscle_priorities = {
        code: "normal"
        for code in all_muscle_codes
    }

    priority_rows = db.execute(
        select(
            MuscleGroup.code,
            UserMusclePriority.priority,
        )
        .join(
            UserMusclePriority,
            UserMusclePriority.muscle_group_id
            == MuscleGroup.id,
        )
        .where(
            UserMusclePriority.user_id
            == user.id
        )
    ).all()

    for muscle_code, priority in priority_rows:
        muscle_priorities[muscle_code] = priority

    selected_equipment = tuple(
        db.scalars(
            select(Equipment.code)
            .join(
                UserEquipment,
                UserEquipment.equipment_id
                == Equipment.id,
            )
            .where(
                UserEquipment.user_id == user.id
            )
            .order_by(
                Equipment.code
            )
        ).all()
    )

    if not selected_equipment:
        raise GeneratorContextError(
            "Equipment selection is missing"
        )

    if "FULL_GYM" in selected_equipment:
        available_equipment = set(
            db.scalars(
                select(Equipment.code).where(
                    Equipment.code != "FULL_GYM"
                )
            ).all()
        )

    else:
        available_equipment = set(
            selected_equipment
        )

        # Bodyweight movements do not require
        # special gym equipment.
        available_equipment.add(
            "BODYWEIGHT"
        )

    sport_rows = list(
        db.scalars(
            select(SportActivity)
            .where(
                SportActivity.user_id == user.id
            )
            .order_by(
                SportActivity.day_of_week,
                SportActivity.sport_type,
            )
        ).all()
    )

    sports = tuple(
        SportContext(
            sport_type=sport.sport_type,
            day_of_week=sport.day_of_week,
            duration_minutes=sport.duration_minutes,
            intensity=sport.intensity,
        )
        for sport in sport_rows
    )

    return GeneratorContext(
        user_id=user.id,

        goal=goal.primary_goal,
        experience_level=profile.experience_level,

        days_per_week=preference.days_per_week,
        available_days=available_days,
        session_duration_minutes=(
            preference.session_duration_minutes
        ),

        no_dedicated_leg_day=(
            preference.no_dedicated_leg_day
        ),
        arm_specialization=(
            preference.arm_specialization
        ),

        muscle_priorities=muscle_priorities,

        equipment_selection=selected_equipment,
        available_equipment=frozenset(
            available_equipment
        ),

        sports=sports,
    )