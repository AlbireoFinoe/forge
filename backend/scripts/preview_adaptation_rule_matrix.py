from decimal import Decimal

from app.services.adaptation_service import (
    decide_adaptation,
)


TEST_CASES = [
    {
        "name": "Insufficient completed sessions",
        "completed_sessions": 1,
        "trend": "insufficient_data",
        "weight": Decimal("70"),
        "rpe": Decimal("8.0"),
        "expected_action": "KEEP_CURRENT",
    },
    {
        "name": "Missing RPE",
        "completed_sessions": 2,
        "trend": "improving",
        "weight": Decimal("70"),
        "rpe": None,
        "expected_action": "KEEP_CURRENT",
    },
    {
        "name": "Improving weighted",
        "completed_sessions": 2,
        "trend": "improving",
        "weight": Decimal("72.5"),
        "rpe": Decimal("8.6"),
        "expected_action": "PROGRESS_LOAD",
    },
    {
        "name": "Improving bodyweight",
        "completed_sessions": 2,
        "trend": "improving",
        "weight": None,
        "rpe": Decimal("8.0"),
        "expected_action": "PROGRESS_REPS",
    },
    {
        "name": "Improving but high RPE",
        "completed_sessions": 2,
        "trend": "improving",
        "weight": Decimal("72.5"),
        "rpe": Decimal("9.5"),
        "expected_action": "HOLD_LOAD",
    },
    {
        "name": "Stable with low RPE",
        "completed_sessions": 2,
        "trend": "stable",
        "weight": Decimal("70"),
        "rpe": Decimal("8.0"),
        "expected_action": "PROGRESS_REPS",
    },
    {
        "name": "Stable with higher RPE",
        "completed_sessions": 2,
        "trend": "stable",
        "weight": Decimal("70"),
        "rpe": Decimal("8.5"),
        "expected_action": "KEEP_CURRENT",
    },
    {
        "name": "Declining with high RPE",
        "completed_sessions": 2,
        "trend": "declining",
        "weight": Decimal("70"),
        "rpe": Decimal("9.0"),
        "expected_action": "REDUCE_STRESS",
    },
    {
        "name": "Declining with manageable RPE",
        "completed_sessions": 2,
        "trend": "declining",
        "weight": Decimal("70"),
        "rpe": Decimal("8.0"),
        "expected_action": "KEEP_CURRENT",
    },
    {
        "name": "Unknown trend",
        "completed_sessions": 2,
        "trend": "insufficient_data",
        "weight": Decimal("70"),
        "rpe": Decimal("8.0"),
        "expected_action": "KEEP_CURRENT",
    },
]


def main():
    print()
    print(
        "FORGE Adaptation Rule Matrix"
    )
    print("=" * 100)

    passed = 0

    for index, case in enumerate(
        TEST_CASES,
        start=1,
    ):
        result = decide_adaptation(
            completed_sessions=(
                case["completed_sessions"]
            ),
            trend=case["trend"],
            latest_weight_kg=(
                case["weight"]
            ),
            latest_average_rpe=(
                case["rpe"]
            ),
        )

        is_pass = (
            result.action
            == case["expected_action"]
        )

        status = (
            "PASS"
            if is_pass
            else "FAIL"
        )

        print(
            f"{index:02d}. "
            f"{case['name']}"
        )

        print(
            f"    Trend: "
            f"{case['trend']}"
        )

        print(
            f"    Weight: "
            f"{case['weight']}"
        )

        print(
            f"    RPE: "
            f"{case['rpe']}"
        )

        print(
            f"    Expected: "
            f"{case['expected_action']}"
        )

        print(
            f"    Actual: "
            f"{result.action}"
        )

        print(
            f"    Reasons: "
            f"{result.reason_codes}"
        )

        print(
            f"    Result: {status}"
        )

        print()

        if not is_pass:
            raise RuntimeError(
                f"Rule matrix failed: "
                f"{case['name']}"
            )

        passed += 1

    print("=" * 100)

    print(
        f"ADAPTATION RULE MATRIX: "
        f"{passed}/{len(TEST_CASES)} PASS"
    )


if __name__ == "__main__":
    main()