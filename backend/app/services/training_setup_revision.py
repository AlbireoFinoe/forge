from app.models.user import User


def bump_training_setup_revision(
    user: User,
) -> None:
    user.training_setup_revision += 1