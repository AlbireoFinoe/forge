from dataclasses import dataclass
from types import SimpleNamespace

from app.generator.fitter import (
    FittedExercise,
    _merge_redundant_one_set_fragments,
)


@dataclass(frozen=True)
class FakeCandidate:
    primary_muscle: str
    contributions: dict[str, float]

    def contribution_for(
        self,
        muscle_code: str,
    ) -> float:
        return self.contributions.get(
            muscle_code,
            0.0,
        )


def _fitted(
    candidate,
    sets,
):
    selected = SimpleNamespace(
        exercise=candidate,
        rest_seconds=60,
    )

    return FittedExercise(
        exercise=selected,
        sets=sets,
    )


def test_one_set_fragment_merges_when_coverage_is_preserved():
    donor = FakeCandidate(
        primary_muscle="CHEST",
        contributions={
            "CHEST": 1.0,
            "TRICEPS": 0.5,
        },
    )

    fragment = FakeCandidate(
        primary_muscle="TRICEPS",
        contributions={
            "TRICEPS": 1.0,
        },
    )

    session = SimpleNamespace(
        target_effective_sets={
            "CHEST": 3.0,
            "TRICEPS": 2.0,
        },
    )

    result = (
        _merge_redundant_one_set_fragments(
            session,
            [
                _fitted(
                    donor,
                    4,
                ),
                _fitted(
                    fragment,
                    1,
                ),
            ],
            available_seconds=99999,
        )
    )

    assert len(result) == 1
    assert result[0].sets == 5


def test_one_set_fragment_stays_when_merge_would_reduce_coverage():
    donor = FakeCandidate(
        primary_muscle="CHEST",
        contributions={
            "CHEST": 1.0,
            "TRICEPS": 0.5,
        },
    )

    fragment = FakeCandidate(
        primary_muscle="TRICEPS",
        contributions={
            "TRICEPS": 1.0,
        },
    )

    session = SimpleNamespace(
        target_effective_sets={
            "CHEST": 3.0,
            "TRICEPS": 3.0,
        },
    )

    result = (
        _merge_redundant_one_set_fragments(
            session,
            [
                _fitted(
                    donor,
                    4,
                ),
                _fitted(
                    fragment,
                    1,
                ),
            ],
            available_seconds=99999,
        )
    )

    assert len(result) == 2
    assert result[0].sets == 4
    assert result[1].sets == 1
