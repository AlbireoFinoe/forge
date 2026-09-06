import argparse

from sqlalchemy import func, select

from app.core.database import (
    SessionLocal,
)
from app.generator.context import (
    build_generator_context,
)
from app.models.program_day import (
    ProgramDay,
)
from app.models.program_exercise import (
    ProgramExercise,
)
from app.models.training_program import (
    TrainingProgram,
)
from app.models.user import User
from app.services.program_service import (
    generate_and_save_program,
)


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--email",
        required=True,
    )

    args = parser.parse_args()

    db = SessionLocal()

    try:
        user = db.scalar(
            select(User).where(
                User.email
                == args.email.lower()
            )
        )

        if user is None:
            print(
                "User not found."
            )
            return

        context = (
            build_generator_context(
                db,
                user,
            )
        )

        result = (
            generate_and_save_program(
                db=db,
                user=user,
                context=context,
            )
        )

        program = (
            result.program
        )

        day_count = db.scalar(
            select(
                func.count(
                    ProgramDay.id
                )
            ).where(
                ProgramDay.program_id
                == program.id
            )
        )

        exercise_count = db.scalar(
            select(
                func.count(
                    ProgramExercise.id
                )
            )
            .join(
                ProgramDay,
                ProgramExercise
                .program_day_id
                == ProgramDay.id,
            )
            .where(
                ProgramDay.program_id
                == program.id
            )
        )

        print()
        print(
            "FORGE Program Persistence"
        )
        print("=" * 80)

        print(
            f"Program ID: "
            f"{program.id}"
        )

        print(
            f"Name: "
            f"{program.name}"
        )

        print(
            f"Version: "
            f"{program.version_number}"
        )

        print(
            f"Generator: "
            f"{program.generator_version}"
        )

        print(
            f"Goal: "
            f"{program.goal}"
        )

        print(
            f"Status: "
            f"{program.status}"
        )

        print(
            f"Validation: "
            f"{result.validation_report.is_valid}"
        )

        print(
            f"Program days: "
            f"{day_count}"
        )

        print(
            f"Program exercises: "
            f"{exercise_count}"
        )

        warning_count = sum(
            1
            for issue
            in result.validation_report.issues
            if issue.severity
            == "warning"
        )

        print(
            f"Warnings: "
            f"{warning_count}"
        )

        print("=" * 80)

    finally:
        db.close()


if __name__ == "__main__":
    main()