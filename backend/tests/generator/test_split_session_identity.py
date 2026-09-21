from app.generator.split import _build_standard_split


def test_standard_four_day_split_has_unique_session_names():
    sessions = _build_standard_split(
        days=4,
        arm_specialization=False,
    )

    names = [
        session.name
        for session in sessions
    ]

    assert len(names) == len(set(names))


def test_standard_four_day_split_has_unique_session_keys():
    sessions = _build_standard_split(
        days=4,
        arm_specialization=False,
    )

    keys = [
        session.key
        for session in sessions
    ]

    assert len(keys) == len(set(keys))
