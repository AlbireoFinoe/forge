from sqlalchemy import delete, select
from sqlalchemy.orm import Session
from datetime import datetime, timezone

from app.models.goal import Goal
from app.models.training_day import TrainingDay
from app.models.training_preference import TrainingPreference
from app.models.user import User
from app.schemas.onboarding import (
    GoalUpdate,
    TrainingPreferencesUpdate,
)
from app.models.secondary_goal import SecondaryGoal


def get_goal(
    db: Session,
    user: User,
) -> Goal | None:
    statement = select(Goal).where(
        Goal.user_id == user.id
    )

    return db.scalar(statement)


def get_secondary_goals(
    db: Session,
    goal: Goal,
) -> list[str]:
    statement = (
        select(SecondaryGoal.goal_type)
        .where(
            SecondaryGoal.goal_id == goal.id
        )
        .order_by(
            SecondaryGoal.goal_type
        )
    )

    return list(
        db.scalars(statement).all()
    )


def set_goal(
    db: Session,
    user: User,
    payload: GoalUpdate,
) -> Goal:
    goal = get_goal(
        db,
        user,
    )

    if goal is None:
        goal = Goal(
            user_id=user.id,
            primary_goal=payload.primary_goal,
        )

        db.add(goal)
        db.flush()

    else:
        goal.primary_goal = payload.primary_goal

    db.execute(
        delete(SecondaryGoal).where(
            SecondaryGoal.goal_id == goal.id
        )
    )

    for secondary_goal in payload.secondary_goals:
        db.add(
            SecondaryGoal(
                goal_id=goal.id,
                goal_type=secondary_goal,
            )
        )

    goal.updated_at = datetime.now(timezone.utc)

    db.commit()
    db.refresh(goal)

    return goal


def get_training_preferences(
    db: Session,
    user: User,
) -> TrainingPreference | None:
    statement = select(
        TrainingPreference
    ).where(
        TrainingPreference.user_id == user.id
    )

    return db.scalar(statement)


def get_training_days(
    db: Session,
    user: User,
) -> list[int]:
    statement = (
        select(TrainingDay.day_of_week)
        .where(
            TrainingDay.user_id == user.id
        )
        .order_by(
            TrainingDay.day_of_week
        )
    )

    return list(
        db.scalars(statement).all()
    )


def set_training_preferences(
    db: Session,
    user: User,
    payload: TrainingPreferencesUpdate,
) -> TrainingPreference:
    preferences = get_training_preferences(
        db,
        user,
    )

    if preferences is None:
        preferences = TrainingPreference(
            user_id=user.id,
            days_per_week=payload.days_per_week,
            session_duration_minutes=(
                payload.session_duration_minutes
            ),
            no_dedicated_leg_day=(
                payload.no_dedicated_leg_day
            ),
            arm_specialization=(
                payload.arm_specialization
            ),
        )

        db.add(preferences)

    else:
        preferences.days_per_week = (
            payload.days_per_week
        )

        preferences.session_duration_minutes = (
            payload.session_duration_minutes
        )

        preferences.no_dedicated_leg_day = (
            payload.no_dedicated_leg_day
        )

        preferences.arm_specialization = (
            payload.arm_specialization
        )

    db.execute(
        delete(TrainingDay).where(
            TrainingDay.user_id == user.id
        )
    )

    for day in payload.available_days:
        db.add(
            TrainingDay(
                user_id=user.id,
                day_of_week=day,
            )
        )

    db.commit()
    db.refresh(preferences)

    return preferences