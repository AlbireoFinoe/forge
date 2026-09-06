from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    status,
)
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
    ProgramGenerateResponse,
    ProgramWarningResponse,
)
from app.services.program_service import (
    ProgramGenerationError,
    generate_and_save_program,
)


router = APIRouter(
    prefix="/programs",
    tags=["Programs"],
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