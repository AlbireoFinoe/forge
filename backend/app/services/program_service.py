from dataclasses import dataclass

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.generator.builder import (
    ProgramBuildResult,
    build_program_plan,
)
from app.generator.context import (
    GeneratorContext,
)
from app.generator.validator import (
    ProgramValidationReport,
    validate_program,
)
from app.models.exercise import Exercise
from app.models.program_day import ProgramDay
from app.models.program_exercise import (
    ProgramExercise,
)
from app.models.training_program import (
    TrainingProgram,
)
from app.models.user import User


GENERATOR_VERSION = "v4"


class ProgramGenerationError(Exception):
    pass


@dataclass(frozen=True)
class PersistedProgramResult:
    program: TrainingProgram

    build_result: ProgramBuildResult

    validation_report: (
        ProgramValidationReport
    )


def _get_next_version_number(
    db: Session,
    user_id,
) -> int:

    latest_version = db.scalar(
        select(
            func.max(
                TrainingProgram.version_number
            )
        ).where(
            TrainingProgram.user_id
            == user_id
        )
    )

    return (
        int(latest_version or 0)
        + 1
    )


def _archive_active_programs(
    db: Session,
    user_id,
) -> None:

    active_programs = db.scalars(
        select(
            TrainingProgram
        ).where(
            TrainingProgram.user_id
            == user_id,
            TrainingProgram.status
            == "active",
        )
    ).all()

    for program in active_programs:
        program.status = "archived"


def _create_training_program(
    db: Session,
    user: User,
    context: GeneratorContext,
    version_number: int,
) -> TrainingProgram:

    program = TrainingProgram(
        user_id=user.id,
        name=(
            f"FORGE Adaptive Program "
            f"v{version_number}"
        ),
        goal=context.goal,
        generator_version=(
            GENERATOR_VERSION
        ),
        version_number=(
            version_number
        ),
        setup_revision=(
            user.training_setup_revision
        ),
        status="active",
    )

    db.add(
        program
    )

    # We need the program UUID before
    # inserting ProgramDay rows.
    db.flush()

    return program


def _create_program_days(
    db: Session,
    program: TrainingProgram,
    build_result: ProgramBuildResult,
) -> None:

    for fitted_session in (
        build_result
        .fitted_program
        .sessions
    ):
        program_day = ProgramDay(
            program_id=program.id,
            day_of_week=(
                fitted_session
                .day_of_week
            ),
            day_order=(
                fitted_session
                .day_order
            ),
            name=(
                fitted_session
                .session_name
            ),
            estimated_duration_minutes=(
                fitted_session
                .estimated_duration_minutes
            ),
        )

        db.add(
            program_day
        )

        # Obtain ProgramDay UUID for
        # ProgramExercise foreign keys.
        db.flush()

        for exercise_order, item in enumerate(
            fitted_session.exercises,
            start=1,
        ):
            selected = (
                item.exercise
            )

            exercise_kwargs = {
                "program_day_id": (
                    program_day.id
                ),
                "exercise_id": (
                    selected
                    .exercise
                    .id
                ),
                "exercise_order": (
                    exercise_order
                ),
                "sets": item.sets,
                "min_reps": (
                    selected.min_reps
                ),
                "max_reps": (
                    selected.max_reps
                ),
                "rest_seconds": (
                    selected.rest_seconds
                ),
            }

            # Your earlier generator design
            # includes reason codes. Add them
            # only when the current ORM model
            # actually exposes that column.
            if hasattr(
                ProgramExercise,
                "reason_codes",
            ):
                exercise_kwargs[
                    "reason_codes"
                ] = list(
                    selected.reason_codes
                )

            program_exercise = (
                ProgramExercise(
                    **exercise_kwargs
                )
            )

            db.add(
                program_exercise
            )


def generate_and_save_program(
    db: Session,
    user: User,
    context: GeneratorContext,
) -> PersistedProgramResult:

    try:
        build_result = (
            build_program_plan(
                db,
                context,
            )
        )

        validation_report = (
            validate_program(
                context,
                build_result,
            )
        )

        if not validation_report.is_valid:
            error_messages = [
                issue.message
                for issue
                in validation_report.issues
                if issue.severity
                == "error"
            ]

            raise ProgramGenerationError(
                "Generated program failed "
                "validation: "
                + "; ".join(
                    error_messages
                )
            )

        version_number = (
            _get_next_version_number(
                db,
                user.id,
            )
        )

        _archive_active_programs(
            db,
            user.id,
        )

        program = (
            _create_training_program(
                db=db,
                user=user,
                context=context,
                version_number=(
                    version_number
                ),
            )
        )

        _create_program_days(
            db=db,
            program=program,
            build_result=(
                build_result
            ),
        )

        db.commit()

        db.refresh(
            program
        )

        return PersistedProgramResult(
            program=program,
            build_result=(
                build_result
            ),
            validation_report=(
                validation_report
            ),
        )

    except Exception:
        db.rollback()
        raise


def get_active_program(
    db: Session,
    user: User,
):
    return db.scalar(
        select(
            TrainingProgram
        )
        .where(
            TrainingProgram.user_id
            == user.id,
            TrainingProgram.status
            == "active",
        )
        .order_by(
            TrainingProgram
            .version_number
            .desc()
        )
        .limit(1)
    )


def get_program_days(
    db: Session,
    program_id,
):
    return db.scalars(
        select(
            ProgramDay
        )
        .where(
            ProgramDay.program_id
            == program_id
        )
        .order_by(
            ProgramDay.day_order
        )
    ).all()


def get_program_day_exercises(
    db: Session,
    program_day_id,
):
    return db.execute(
        select(
            ProgramExercise,
            Exercise,
        )
        .join(
            Exercise,
            ProgramExercise.exercise_id
            == Exercise.id,
        )
        .where(
            ProgramExercise.program_day_id
            == program_day_id
        )
        .order_by(
            ProgramExercise.exercise_order
        )
    ).all()


def get_user_program_history(
    db: Session,
    user: User,
):
    return db.scalars(
        select(
            TrainingProgram
        )
        .where(
            TrainingProgram.user_id
            == user.id
        )
        .order_by(
            TrainingProgram
            .version_number
            .desc()
        )
    ).all()


def get_user_program_by_id(
    db: Session,
    user: User,
    program_id,
):
    return db.scalar(
        select(
            TrainingProgram
        ).where(
            TrainingProgram.id
            == program_id,
            TrainingProgram.user_id
            == user.id,
        )
    )

