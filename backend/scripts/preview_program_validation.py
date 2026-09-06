import argparse

from sqlalchemy import select

from app.core.database import (
    SessionLocal,
)
from app.generator.builder import (
    build_program_plan,
)
from app.generator.context import (
    build_generator_context,
)
from app.generator.validator import (
    validate_program,
)
from app.models.user import User


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
            print("User not found.")
            return

        context = (
            build_generator_context(
                db,
                user,
            )
        )

        result = build_program_plan(
            db,
            context,
        )

        report = validate_program(
            context,
            result,
        )

        print()
        print(
            "FORGE Final Validation"
        )
        print("=" * 90)

        print(
            "VALID:"
            f" {report.is_valid}"
        )

        print()
        print(
            "Weekly effective volume"
        )
        print("-" * 90)

        for item in (
            report.muscle_volumes
        ):
            print(
                f"{item.muscle_code:<16}"
                f"priority="
                f"{item.priority:<12}"
                f"target="
                f"{item.target_effective_sets:<6}"
                f"actual="
                f"{item.actual_effective_sets:<6}"
                f"ratio="
                f"{item.ratio:.0%}"
            )

        print()
        print("Issues")
        print("-" * 90)

        if not report.issues:
            print(
                "No validation issues."
            )

        else:
            for issue in report.issues:
                print(
                    f"[{issue.severity.upper():<7}] "
                    f"{issue.code}"
                )

                print(
                    f"          "
                    f"{issue.message}"
                )

        print()
        print("=" * 90)

    finally:
        db.close()


if __name__ == "__main__":
    main()