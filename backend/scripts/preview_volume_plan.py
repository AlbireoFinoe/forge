import argparse

from sqlalchemy import select

from app.core.database import SessionLocal
from app.generator.context import (
    GeneratorContextError,
    build_generator_context,
)
from app.generator.volume import (
    VolumeEngineError,
    calculate_volume_plan,
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
                User.email == args.email.lower()
            )
        )

        if user is None:
            print("User not found.")
            return

        try:
            context = build_generator_context(
                db,
                user,
            )

            plan = calculate_volume_plan(
                context
            )

        except (
            GeneratorContextError,
            VolumeEngineError,
        ) as exc:
            print(
                f"Generator error: {exc}"
            )
            return

        print()
        print(
            "FORGE Volume Plan"
        )
        print(
            "=" * 72
        )

        print(
            f"{'Muscle':<16}"
            f"{'Priority':<14}"
            f"{'Base':>8}"
            f"{'Goal':>8}"
            f"{'Bonus':>8}"
            f"{'Target':>10}"
        )

        print(
            "-" * 72
        )

        for target in plan.targets.values():
            print(
                f"{target.muscle_code:<16}"
                f"{target.priority:<14}"
                f"{target.base_sets:>8}"
                f"{target.goal_adjusted_sets:>8}"
                f"{target.specialization_bonus:>8}"
                f"{target.target_effective_sets:>10}"
            )

        print(
            "-" * 72
        )

        print(
            "Total effective-set targets:",
            plan.total_target_effective_sets,
        )

    finally:
        db.close()


if __name__ == "__main__":
    main()