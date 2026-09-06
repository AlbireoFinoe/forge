from dataclasses import dataclass

from app.generator.context import GeneratorContext


PRIORITY_TARGETS = {
    "beginner": {
        "maintenance": 4,
        "normal": 8,
        "high": 10,
    },
    "intermediate": {
        "maintenance": 6,
        "normal": 10,
        "high": 14,
    },
    "advanced": {
        "maintenance": 8,
        "normal": 12,
        "high": 16,
    },
}


GOAL_MULTIPLIERS = {
    "muscle_gain": 1.00,
    "strength": 0.90,
    "fat_loss": 0.80,
    "general_fitness": 0.80,
    "hybrid": 0.85,
}


ARM_MUSCLES = {
    "BICEPS",
    "TRICEPS",
}


@dataclass(frozen=True)
class MuscleVolumeTarget:
    muscle_code: str
    priority: str

    base_sets: int
    goal_adjusted_sets: int
    specialization_bonus: int

    target_effective_sets: int


@dataclass(frozen=True)
class VolumePlan:
    targets: dict[str, MuscleVolumeTarget]

    @property
    def total_target_effective_sets(self) -> int:
        return sum(
            target.target_effective_sets
            for target in self.targets.values()
        )


class VolumeEngineError(Exception):
    pass


def _round_sets(value: float) -> int:
    return max(
        1,
        round(value),
    )


def calculate_volume_plan(
    context: GeneratorContext,
) -> VolumePlan:
    experience_targets = PRIORITY_TARGETS.get(
        context.experience_level
    )

    if experience_targets is None:
        raise VolumeEngineError(
            f"Unsupported experience level: "
            f"{context.experience_level}"
        )

    goal_multiplier = GOAL_MULTIPLIERS.get(
        context.goal
    )

    if goal_multiplier is None:
        raise VolumeEngineError(
            f"Unsupported training goal: {context.goal}"
        )

    targets: dict[str, MuscleVolumeTarget] = {}

    for muscle_code, priority in sorted(
        context.muscle_priorities.items()
    ):
        base_sets = experience_targets.get(
            priority
        )

        if base_sets is None:
            raise VolumeEngineError(
                f"Unsupported priority '{priority}' "
                f"for muscle '{muscle_code}'"
            )

        goal_adjusted_sets = _round_sets(
            base_sets * goal_multiplier
        )

        specialization_bonus = 0

        if (
            context.arm_specialization
            and muscle_code in ARM_MUSCLES
            and priority == "high"
        ):
            specialization_bonus = 2

        target_sets = (
            goal_adjusted_sets
            + specialization_bonus
        )

        # Safety ceiling for generator v1.
        target_sets = min(
            target_sets,
            18,
        )

        targets[muscle_code] = MuscleVolumeTarget(
            muscle_code=muscle_code,
            priority=priority,
            base_sets=base_sets,
            goal_adjusted_sets=goal_adjusted_sets,
            specialization_bonus=(
                specialization_bonus
            ),
            target_effective_sets=target_sets,
        )

    return VolumePlan(
        targets=targets
    )