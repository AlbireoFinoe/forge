from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    status,
)
from uuid import UUID

from sqlalchemy.orm import Session

from app.api.deps import (
    get_current_user,
)
from app.core.database import get_db
from app.generator.context import (
    GeneratorContextError,
    build_generator_context,
)
from app.models.user import User
from app.schemas.program import (
    ProgramDayResponse,
    ProgramDetailResponse,
    ProgramExerciseResponse,
    ProgramGenerateResponse,
    ProgramSummaryResponse,
    ProgramWarningResponse,
)
from app.services.program_service import (
    ProgramGenerationError,
    generate_and_save_program,
    get_active_program,
    get_program_day_exercises,
    get_program_days,
    get_user_program_by_id,
    get_user_program_history,
)


router = APIRouter(
    prefix="/programs",
    tags=["Programs"],
)


def _build_program_detail_response(
    db: Session,
    program,
    current_setup_revision: int,
) -> ProgramDetailResponse:

    day_rows = get_program_days(
        db,
        program.id,
    )

    days = []

    for day in day_rows:
        exercise_rows = (
            get_program_day_exercises(
                db,
                day.id,
            )
        )

        exercises = []

        for (
            program_exercise,
            exercise,
        ) in exercise_rows:

            reason_codes = []

            if hasattr(
                program_exercise,
                "reason_codes",
            ):
                reason_codes = (
                    program_exercise
                    .reason_codes
                    or []
                )

            exercises.append(
                ProgramExerciseResponse(
                    id=program_exercise.id,
                    exercise_id=exercise.id,
                    exercise_code=(
                        exercise.code
                    ),
                    exercise_name=(
                        exercise.name
                    ),
                    exercise_order=(
                        program_exercise
                        .exercise_order
                    ),
                    sets=(
                        program_exercise.sets
                    ),
                    min_reps=(
                        program_exercise
                        .min_reps
                    ),
                    max_reps=(
                        program_exercise
                        .max_reps
                    ),
                    rest_seconds=(
                        program_exercise
                        .rest_seconds
                    ),
                    reason_codes=(
                        reason_codes
                    ),
                )
            )

        days.append(
            ProgramDayResponse(
                id=day.id,
                day_of_week=(
                    day.day_of_week
                ),
                day_order=(
                    day.day_order
                ),
                name=day.name,
                estimated_duration_minutes=(
                    day
                    .estimated_duration_minutes
                ),
                exercises=exercises,
            )
        )

    return ProgramDetailResponse(
        id=program.id,
        name=program.name,
        version_number=(
            program.version_number
        ),
        generator_version=(
            program.generator_version
        ),
        setup_revision=(
            program.setup_revision
        ),
        current_setup_revision=(
            current_setup_revision
        ),
        is_outdated=(
            program.setup_revision
            != current_setup_revision
        ),
        goal=program.goal,
        status=program.status,
        created_at=program.created_at,
        days=days,
    )


@router.post(
    "/generate",
    response_model=ProgramGenerateResponse,
    status_code=status.HTTP_201_CREATED,
)
def generate_program(
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(get_db),
):
    try:
        context = (
            build_generator_context(
                db,
                current_user,
            )
        )

        result = (
            generate_and_save_program(
                db=db,
                user=current_user,
                context=context,
            )
        )

    except GeneratorContextError as exc:
        raise HTTPException(
            status_code=(
                status.HTTP_422_UNPROCESSABLE_ENTITY
            ),
            detail=str(exc),
        ) from exc

    except ProgramGenerationError as exc:
        raise HTTPException(
            status_code=(
                status.HTTP_422_UNPROCESSABLE_ENTITY
            ),
            detail=str(exc),
        ) from exc

    program = result.program

    fitted_sessions = (
        result
        .build_result
        .fitted_program
        .sessions
    )

    program_days = len(
        fitted_sessions
    )

    program_exercises = sum(
        len(session.exercises)
        for session in fitted_sessions
    )

    warnings = [
        ProgramWarningResponse(
            code=issue.code,
            message=issue.message,
        )
        for issue
        in result.validation_report.issues
        if issue.severity == "warning"
    ]

    return ProgramGenerateResponse(
        id=program.id,
        name=program.name,
        version_number=(
            program.version_number
        ),
        generator_version=(
            program.generator_version
        ),
        setup_revision=(
            program.setup_revision
        ),
        current_setup_revision=(
            current_user
            .training_setup_revision
        ),
        is_outdated=(
            program.setup_revision
            != current_user
            .training_setup_revision
        ),
        goal=program.goal,
        status=program.status,
        validation_passed=(
            result
            .validation_report
            .is_valid
        ),
        program_days=program_days,
        program_exercises=(
            program_exercises
        ),
        warnings=warnings,
        created_at=(
            program.created_at
        ),
    )


@router.get(
    "/current",
    response_model=ProgramDetailResponse,
)
def get_current_program(
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(get_db),
):
    program = get_active_program(
        db,
        current_user,
    )

    if program is None:
        raise HTTPException(
            status_code=(
                status.HTTP_404_NOT_FOUND
            ),
            detail=(
                "No active training "
                "program found"
            ),
        )

    return _build_program_detail_response(
        db,
        program,
        current_user.training_setup_revision,
    )


@router.get(
    "/history",
    response_model=list[
        ProgramSummaryResponse
    ],
)
def get_program_history(
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(get_db),
):
    programs = (
        get_user_program_history(
            db,
            current_user,
        )
    )

    return [
        ProgramSummaryResponse(
            id=program.id,
            name=program.name,
            version_number=(
                program.version_number
            ),
            generator_version=(
                program.generator_version
            ),
            setup_revision=(
                program.setup_revision
            ),
            current_setup_revision=(
                current_user
                .training_setup_revision
            ),
            is_outdated=(
                program.setup_revision
                != current_user
                .training_setup_revision
            ),
            goal=program.goal,
            status=program.status,
            created_at=(
                program.created_at
            ),
        )
        for program in programs
    ]


@router.get(
    "/{program_id}",
    response_model=ProgramDetailResponse,
)
def get_program_by_id(
    program_id: UUID,
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(get_db),
):
    program = get_user_program_by_id(
        db,
        current_user,
        program_id,
    )

    if program is None:
        raise HTTPException(
            status_code=(
                status.HTTP_404_NOT_FOUND
            ),
            detail=(
                "Training program "
                "not found"
            ),
        )

    return _build_program_detail_response(
        db,
        program,
        current_user.training_setup_revision,
    )