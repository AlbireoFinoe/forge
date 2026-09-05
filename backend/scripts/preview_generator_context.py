import argparse
from dataclasses import asdict
from pprint import pprint

from sqlalchemy import select

from app.core.database import SessionLocal
from app.generator.context import (
    GeneratorContextError,
    build_generator_context,
)
from app.models.user import User


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--email",
        required=True,
        help="Email of the user to inspect",
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

        except GeneratorContextError as exc:
            print(
                f"Generator context error: {exc}"
            )
            return

        pprint(
            asdict(context),
            sort_dicts=False,
        )

    finally:
        db.close()


if __name__ == "__main__":
    main()