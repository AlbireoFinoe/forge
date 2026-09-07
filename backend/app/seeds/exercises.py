from sqlalchemy import delete, select

from app.core.database import SessionLocal
from app.models.equipment import Equipment
from app.models.exercise import Exercise
from app.models.exercise_equipment import ExerciseEquipment
from app.models.exercise_secondary_muscle import ExerciseSecondaryMuscle
from app.models.muscle_group import MuscleGroup


EXERCISES = [
    # =========================
    # CHEST
    # =========================
    {
        "code": "BARBELL_BENCH_PRESS",
        "name": "Barbell Bench Press",
        "primary": "CHEST",
        "movement": "horizontal_push",
        "difficulty": "intermediate",
        "compound": True,
        "min_reps": 5,
        "max_reps": 10,
        "rest": 180,
        "equipment": ["BARBELL", "BENCH"],
        "secondary": {
            "TRICEPS": 0.5,
            "FRONT_DELTS": 0.5,
        },
    },
    {
        "code": "DUMBBELL_BENCH_PRESS",
        "name": "Dumbbell Bench Press",
        "primary": "CHEST",
        "movement": "horizontal_push",
        "difficulty": "beginner",
        "compound": True,
        "min_reps": 6,
        "max_reps": 12,
        "rest": 150,
        "equipment": ["DUMBBELL", "BENCH"],
        "secondary": {
            "TRICEPS": 0.5,
            "FRONT_DELTS": 0.5,
        },
    },
    {
        "code": "INCLINE_DUMBBELL_PRESS",
        "name": "Incline Dumbbell Press",
        "primary": "CHEST",
        "movement": "incline_push",
        "difficulty": "beginner",
        "compound": True,
        "min_reps": 6,
        "max_reps": 12,
        "rest": 150,
        "equipment": ["DUMBBELL", "BENCH"],
        "secondary": {
            "TRICEPS": 0.5,
            "FRONT_DELTS": 0.6,
        },
    },
    {
        "code": "INCLINE_SMITH_PRESS",
        "name": "Incline Smith Machine Press",
        "primary": "CHEST",
        "movement": "incline_push",
        "difficulty": "beginner",
        "compound": True,
        "min_reps": 6,
        "max_reps": 12,
        "rest": 150,
        "equipment": ["SMITH_MACHINE", "BENCH"],
        "secondary": {
            "TRICEPS": 0.5,
            "FRONT_DELTS": 0.6,
        },
    },
    {
        "code": "CABLE_CHEST_FLY",
        "name": "Cable Chest Fly",
        "primary": "CHEST",
        "movement": "chest_adduction",
        "difficulty": "beginner",
        "compound": False,
        "min_reps": 10,
        "max_reps": 15,
        "rest": 90,
        "equipment": ["CABLE"],
        "secondary": {},
    },
    {
        "code": "PUSH_UP",
        "name": "Push-Up",
        "primary": "CHEST",
        "movement": "horizontal_push",
        "difficulty": "beginner",
        "compound": True,
        "min_reps": 8,
        "max_reps": 20,
        "rest": 90,
        "equipment": ["BODYWEIGHT"],
        "secondary": {
            "TRICEPS": 0.5,
            "FRONT_DELTS": 0.4,
        },
    },

    # =========================
    # BACK
    # =========================
    {
        "code": "LAT_PULLDOWN",
        "name": "Lat Pulldown",
        "primary": "BACK",
        "movement": "vertical_pull",
        "difficulty": "beginner",
        "compound": True,
        "min_reps": 8,
        "max_reps": 12,
        "rest": 120,
        "equipment": ["CABLE"],
        "secondary": {
            "BICEPS": 0.5,
            "FOREARMS": 0.25,
        },
    },
    {
        "code": "PULL_UP",
        "name": "Pull-Up",
        "primary": "BACK",
        "movement": "vertical_pull",
        "difficulty": "intermediate",
        "compound": True,
        "min_reps": 5,
        "max_reps": 12,
        "rest": 150,
        "equipment": ["PULLUP_BAR"],
        "secondary": {
            "BICEPS": 0.5,
            "FOREARMS": 0.25,
        },
    },
    {
        "code": "BARBELL_ROW",
        "name": "Barbell Row",
        "primary": "BACK",
        "movement": "horizontal_pull",
        "difficulty": "intermediate",
        "compound": True,
        "min_reps": 6,
        "max_reps": 10,
        "rest": 150,
        "equipment": ["BARBELL"],
        "secondary": {
            "BICEPS": 0.4,
            "REAR_DELTS": 0.4,
            "TRAPS": 0.4,
        },
    },
    {
        "code": "CHEST_SUPPORTED_DUMBBELL_ROW",
        "name": "Chest Supported Dumbbell Row",
        "primary": "BACK",
        "movement": "horizontal_pull",
        "difficulty": "beginner",
        "compound": True,
        "min_reps": 8,
        "max_reps": 12,
        "rest": 120,
        "equipment": ["DUMBBELL", "BENCH"],
        "secondary": {
            "BICEPS": 0.4,
            "REAR_DELTS": 0.4,
        },
    },
    {
        "code": "ONE_ARM_DUMBBELL_ROW",
        "name": "One-Arm Dumbbell Row",
        "primary": "BACK",
        "movement": "horizontal_pull",
        "difficulty": "beginner",
        "compound": True,
        "min_reps": 8,
        "max_reps": 15,
        "rest": 120,
        "equipment": ["DUMBBELL"],
        "secondary": {
            "BICEPS": 0.4,
            "REAR_DELTS": 0.4,
            "TRAPS": 0.25,
        },
    },
    {
        "code": "SEATED_CABLE_ROW",
        "name": "Seated Cable Row",
        "primary": "BACK",
        "movement": "horizontal_pull",
        "difficulty": "beginner",
        "compound": True,
        "min_reps": 8,
        "max_reps": 12,
        "rest": 120,
        "equipment": ["CABLE"],
        "secondary": {
            "BICEPS": 0.4,
            "REAR_DELTS": 0.4,
        },
    },
    {
        "code": "MACHINE_ROW",
        "name": "Machine Row",
        "primary": "BACK",
        "movement": "horizontal_pull",
        "difficulty": "beginner",
        "compound": True,
        "min_reps": 8,
        "max_reps": 12,
        "rest": 120,
        "equipment": ["MACHINE"],
        "secondary": {
            "BICEPS": 0.4,
            "REAR_DELTS": 0.4,
        },
    },
    {
        "code": "STRAIGHT_ARM_PULLDOWN",
        "name": "Straight Arm Pulldown",
        "primary": "BACK",
        "movement": "shoulder_extension",
        "difficulty": "beginner",
        "compound": False,
        "min_reps": 10,
        "max_reps": 15,
        "rest": 90,
        "equipment": ["CABLE"],
        "secondary": {},
    },

    # =========================
    # SHOULDERS
    # =========================
    {
        "code": "DUMBBELL_SHOULDER_PRESS",
        "name": "Dumbbell Shoulder Press",
        "primary": "FRONT_DELTS",
        "movement": "vertical_push",
        "difficulty": "beginner",
        "compound": True,
        "min_reps": 6,
        "max_reps": 12,
        "rest": 150,
        "equipment": ["DUMBBELL"],
        "secondary": {
            "TRICEPS": 0.5,
            "SIDE_DELTS": 0.4,
        },
    },
    {
        "code": "BARBELL_OVERHEAD_PRESS",
        "name": "Barbell Overhead Press",
        "primary": "FRONT_DELTS",
        "movement": "vertical_push",
        "difficulty": "intermediate",
        "compound": True,
        "min_reps": 6,
        "max_reps": 12,
        "rest": 150,
        "equipment": ["BARBELL"],
        "secondary": {
            "TRICEPS": 0.5,
            "SIDE_DELTS": 0.4,
        },
    },
    {
        "code": "MACHINE_SHOULDER_PRESS",
        "name": "Machine Shoulder Press",
        "primary": "FRONT_DELTS",
        "movement": "vertical_push",
        "difficulty": "beginner",
        "compound": True,
        "min_reps": 8,
        "max_reps": 12,
        "rest": 120,
        "equipment": ["MACHINE"],
        "secondary": {
            "TRICEPS": 0.5,
            "SIDE_DELTS": 0.4,
        },
    },
    {
        "code": "DUMBBELL_LATERAL_RAISE",
        "name": "Dumbbell Lateral Raise",
        "primary": "SIDE_DELTS",
        "movement": "shoulder_abduction",
        "difficulty": "beginner",
        "compound": False,
        "min_reps": 10,
        "max_reps": 20,
        "rest": 75,
        "equipment": ["DUMBBELL"],
        "secondary": {},
    },
    {
        "code": "CABLE_LATERAL_RAISE",
        "name": "Cable Lateral Raise",
        "primary": "SIDE_DELTS",
        "movement": "shoulder_abduction",
        "difficulty": "beginner",
        "compound": False,
        "min_reps": 10,
        "max_reps": 20,
        "rest": 75,
        "equipment": ["CABLE"],
        "secondary": {},
    },
    {
        "code": "REVERSE_PEC_DECK",
        "name": "Reverse Pec Deck",
        "primary": "REAR_DELTS",
        "movement": "reverse_fly",
        "difficulty": "beginner",
        "compound": False,
        "min_reps": 10,
        "max_reps": 20,
        "rest": 75,
        "equipment": ["MACHINE"],
        "secondary": {
            "BACK": 0.25,
        },
    },
    {
        "code": "CABLE_REAR_DELT_FLY",
        "name": "Cable Rear Delt Fly",
        "primary": "REAR_DELTS",
        "movement": "reverse_fly",
        "difficulty": "beginner",
        "compound": False,
        "min_reps": 10,
        "max_reps": 20,
        "rest": 75,
        "equipment": ["CABLE"],
        "secondary": {
            "BACK": 0.25,
        },
    },
    {
        "code": "DUMBBELL_REAR_DELT_FLY",
        "name": "Bent-Over Dumbbell Rear Delt Fly",
        "primary": "REAR_DELTS",
        "movement": "reverse_fly",
        "difficulty": "beginner",
        "compound": False,
        "min_reps": 10,
        "max_reps": 20,
        "rest": 75,
        "equipment": ["DUMBBELL"],
        "secondary": {
            "BACK": 0.25,
        },
    },
    {
        "code": "BARBELL_REAR_DELT_ROW",
        "name": "Barbell Rear Delt Row",
        "primary": "REAR_DELTS",
        "movement": "rear_delt_row",
        "difficulty": "intermediate",
        "compound": True,
        "min_reps": 8,
        "max_reps": 15,
        "rest": 120,
        "equipment": ["BARBELL"],
        "secondary": {
            "BACK": 0.4,
            "TRAPS": 0.25,
        },
    },

    # =========================
    # BICEPS
    # =========================
    {
        "code": "DUMBBELL_CURL",
        "name": "Dumbbell Curl",
        "primary": "BICEPS",
        "movement": "elbow_flexion",
        "difficulty": "beginner",
        "compound": False,
        "min_reps": 8,
        "max_reps": 15,
        "rest": 90,
        "equipment": ["DUMBBELL"],
        "secondary": {
            "FOREARMS": 0.25,
        },
    },
    {
        "code": "BARBELL_CURL",
        "name": "Barbell Curl",
        "primary": "BICEPS",
        "movement": "elbow_flexion",
        "difficulty": "beginner",
        "compound": False,
        "min_reps": 8,
        "max_reps": 15,
        "rest": 90,
        "equipment": ["BARBELL"],
        "secondary": {
            "FOREARMS": 0.25,
        },
    },
    {
        "code": "HAMMER_CURL",
        "name": "Hammer Curl",
        "primary": "BICEPS",
        "movement": "elbow_flexion",
        "difficulty": "beginner",
        "compound": False,
        "min_reps": 8,
        "max_reps": 15,
        "rest": 90,
        "equipment": ["DUMBBELL"],
        "secondary": {
            "FOREARMS": 0.5,
        },
    },
    {
        "code": "INCLINE_DUMBBELL_CURL",
        "name": "Incline Dumbbell Curl",
        "primary": "BICEPS",
        "movement": "elbow_flexion",
        "difficulty": "intermediate",
        "compound": False,
        "min_reps": 8,
        "max_reps": 15,
        "rest": 90,
        "equipment": ["DUMBBELL", "BENCH"],
        "secondary": {
            "FOREARMS": 0.2,
        },
    },
    {
        "code": "CABLE_CURL",
        "name": "Cable Curl",
        "primary": "BICEPS",
        "movement": "elbow_flexion",
        "difficulty": "beginner",
        "compound": False,
        "min_reps": 8,
        "max_reps": 15,
        "rest": 90,
        "equipment": ["CABLE"],
        "secondary": {
            "FOREARMS": 0.2,
        },
    },
    {
        "code": "MACHINE_PREACHER_CURL",
        "name": "Machine Preacher Curl",
        "primary": "BICEPS",
        "movement": "elbow_flexion",
        "difficulty": "beginner",
        "compound": False,
        "min_reps": 8,
        "max_reps": 15,
        "rest": 90,
        "equipment": ["MACHINE"],
        "secondary": {
            "FOREARMS": 0.2,
        },
    },

    # =========================
    # FOREARMS
    # =========================
    {
        "code": "DUMBBELL_REVERSE_CURL",
        "name": "Dumbbell Reverse Curl",
        "primary": "FOREARMS",
        "movement": "pronated_elbow_flexion",
        "difficulty": "beginner",
        "compound": False,
        "min_reps": 10,
        "max_reps": 15,
        "rest": 75,
        "equipment": ["DUMBBELL"],
        "secondary": {
            "BICEPS": 0.4,
        },
    },
    {
        "code": "BARBELL_REVERSE_CURL",
        "name": "Barbell Reverse Curl",
        "primary": "FOREARMS",
        "movement": "pronated_elbow_flexion",
        "difficulty": "beginner",
        "compound": False,
        "min_reps": 10,
        "max_reps": 15,
        "rest": 75,
        "equipment": ["BARBELL"],
        "secondary": {
            "BICEPS": 0.4,
        },
    },
    {
        "code": "DUMBBELL_WRIST_CURL",
        "name": "Dumbbell Wrist Curl",
        "primary": "FOREARMS",
        "movement": "wrist_flexion",
        "difficulty": "beginner",
        "compound": False,
        "min_reps": 12,
        "max_reps": 20,
        "rest": 60,
        "equipment": ["DUMBBELL"],
        "secondary": {},
    },

    # =========================
    # TRICEPS
    # =========================
    {
        "code": "TRICEPS_PUSHDOWN",
        "name": "Triceps Pushdown",
        "primary": "TRICEPS",
        "movement": "elbow_extension",
        "difficulty": "beginner",
        "compound": False,
        "min_reps": 8,
        "max_reps": 15,
        "rest": 90,
        "equipment": ["CABLE"],
        "secondary": {},
    },
    {
        "code": "OVERHEAD_CABLE_TRICEPS_EXTENSION",
        "name": "Overhead Cable Triceps Extension",
        "primary": "TRICEPS",
        "movement": "elbow_extension",
        "difficulty": "beginner",
        "compound": False,
        "min_reps": 8,
        "max_reps": 15,
        "rest": 90,
        "equipment": ["CABLE"],
        "secondary": {},
    },
    {
        "code": "DUMBBELL_OVERHEAD_TRICEPS_EXTENSION",
        "name": "Dumbbell Overhead Triceps Extension",
        "primary": "TRICEPS",
        "movement": "elbow_extension",
        "difficulty": "beginner",
        "compound": False,
        "min_reps": 8,
        "max_reps": 15,
        "rest": 90,
        "equipment": ["DUMBBELL"],
        "secondary": {},
    },
    {
        "code": "BARBELL_FLOOR_PRESS",
        "name": "Close-Grip Barbell Floor Press",
        "primary": "TRICEPS",
        "movement": "horizontal_push",
        "difficulty": "intermediate",
        "compound": True,
        "min_reps": 6,
        "max_reps": 12,
        "rest": 150,
        "equipment": ["BARBELL"],
        "secondary": {
            "CHEST": 0.5,
            "FRONT_DELTS": 0.3,
        },
    },
    {
        "code": "CLOSE_GRIP_BENCH_PRESS",
        "name": "Close Grip Bench Press",
        "primary": "TRICEPS",
        "movement": "horizontal_push",
        "difficulty": "intermediate",
        "compound": True,
        "min_reps": 6,
        "max_reps": 10,
        "rest": 150,
        "equipment": ["BARBELL", "BENCH"],
        "secondary": {
            "CHEST": 0.5,
            "FRONT_DELTS": 0.3,
        },
    },
    {
        "code": "MACHINE_TRICEPS_DIP",
        "name": "Machine Triceps Dip",
        "primary": "TRICEPS",
        "movement": "press_down",
        "difficulty": "beginner",
        "compound": True,
        "min_reps": 8,
        "max_reps": 12,
        "rest": 120,
        "equipment": ["MACHINE"],
        "secondary": {
            "CHEST": 0.4,
            "FRONT_DELTS": 0.2,
        },
    },

    # =========================
    # TRAPS
    # =========================
    {
        "code": "DUMBBELL_SHRUG",
        "name": "Dumbbell Shrug",
        "primary": "TRAPS",
        "movement": "scapular_elevation",
        "difficulty": "beginner",
        "compound": False,
        "min_reps": 8,
        "max_reps": 15,
        "rest": 90,
        "equipment": ["DUMBBELL"],
        "secondary": {
            "FOREARMS": 0.25,
        },
    },
    {
        "code": "BARBELL_SHRUG",
        "name": "Barbell Shrug",
        "primary": "TRAPS",
        "movement": "scapular_elevation",
        "difficulty": "beginner",
        "compound": False,
        "min_reps": 8,
        "max_reps": 15,
        "rest": 90,
        "equipment": ["BARBELL"],
        "secondary": {
            "FOREARMS": 0.25,
        },
    },
    {
        "code": "CABLE_SHRUG",
        "name": "Cable Shrug",
        "primary": "TRAPS",
        "movement": "scapular_elevation",
        "difficulty": "beginner",
        "compound": False,
        "min_reps": 10,
        "max_reps": 15,
        "rest": 90,
        "equipment": ["CABLE"],
        "secondary": {},
    },

    # =========================
    # QUADS
    # =========================
    {
        "code": "GOBLET_SQUAT",
        "name": "Goblet Squat",
        "primary": "QUADS",
        "movement": "squat",
        "difficulty": "beginner",
        "compound": True,
        "min_reps": 8,
        "max_reps": 15,
        "rest": 120,
        "equipment": ["DUMBBELL"],
        "secondary": {
            "GLUTES": 0.5,
            "HAMSTRINGS": 0.2,
        },
    },
    {
        "code": "BARBELL_SQUAT",
        "name": "Barbell Squat",
        "primary": "QUADS",
        "movement": "squat",
        "difficulty": "intermediate",
        "compound": True,
        "min_reps": 5,
        "max_reps": 10,
        "rest": 180,
        "equipment": ["BARBELL"],
        "secondary": {
            "GLUTES": 0.6,
            "HAMSTRINGS": 0.25,
        },
    },
    {
        "code": "SMITH_SQUAT",
        "name": "Smith Machine Squat",
        "primary": "QUADS",
        "movement": "squat",
        "difficulty": "beginner",
        "compound": True,
        "min_reps": 6,
        "max_reps": 12,
        "rest": 150,
        "equipment": ["SMITH_MACHINE"],
        "secondary": {
            "GLUTES": 0.5,
        },
    },
    {
        "code": "LEG_PRESS",
        "name": "Leg Press",
        "primary": "QUADS",
        "movement": "squat",
        "difficulty": "beginner",
        "compound": True,
        "min_reps": 8,
        "max_reps": 15,
        "rest": 150,
        "equipment": ["MACHINE"],
        "secondary": {
            "GLUTES": 0.5,
            "HAMSTRINGS": 0.2,
        },
    },
    {
        "code": "LEG_EXTENSION",
        "name": "Leg Extension",
        "primary": "QUADS",
        "movement": "knee_extension",
        "difficulty": "beginner",
        "compound": False,
        "min_reps": 10,
        "max_reps": 20,
        "rest": 90,
        "equipment": ["MACHINE"],
        "secondary": {},
    },

    # =========================
    # HAMSTRINGS / GLUTES
    # =========================
    {
        "code": "BARBELL_RDL",
        "name": "Barbell Romanian Deadlift",
        "primary": "HAMSTRINGS",
        "movement": "hip_hinge",
        "difficulty": "intermediate",
        "compound": True,
        "min_reps": 6,
        "max_reps": 12,
        "rest": 180,
        "equipment": ["BARBELL"],
        "secondary": {
            "GLUTES": 0.6,
            "BACK": 0.25,
        },
    },
    {
        "code": "DUMBBELL_RDL",
        "name": "Dumbbell Romanian Deadlift",
        "primary": "HAMSTRINGS",
        "movement": "hip_hinge",
        "difficulty": "beginner",
        "compound": True,
        "min_reps": 8,
        "max_reps": 12,
        "rest": 150,
        "equipment": ["DUMBBELL"],
        "secondary": {
            "GLUTES": 0.6,
            "BACK": 0.2,
        },
    },
    {
        "code": "LYING_LEG_CURL",
        "name": "Lying Leg Curl",
        "primary": "HAMSTRINGS",
        "movement": "knee_flexion",
        "difficulty": "beginner",
        "compound": False,
        "min_reps": 10,
        "max_reps": 15,
        "rest": 90,
        "equipment": ["MACHINE"],
        "secondary": {},
    },
    {
        "code": "SEATED_LEG_CURL",
        "name": "Seated Leg Curl",
        "primary": "HAMSTRINGS",
        "movement": "knee_flexion",
        "difficulty": "beginner",
        "compound": False,
        "min_reps": 10,
        "max_reps": 15,
        "rest": 90,
        "equipment": ["MACHINE"],
        "secondary": {},
    },
    {
        "code": "BARBELL_HIP_THRUST",
        "name": "Barbell Hip Thrust",
        "primary": "GLUTES",
        "movement": "hip_extension",
        "difficulty": "intermediate",
        "compound": True,
        "min_reps": 6,
        "max_reps": 12,
        "rest": 150,
        "equipment": ["BARBELL", "BENCH"],
        "secondary": {
            "HAMSTRINGS": 0.3,
        },
    },

    # =========================
    # CALVES
    # =========================
    {
        "code": "DUMBBELL_CALF_RAISE",
        "name": "Standing Dumbbell Calf Raise",
        "primary": "CALVES",
        "movement": "plantar_flexion",
        "difficulty": "beginner",
        "compound": False,
        "min_reps": 10,
        "max_reps": 20,
        "rest": 75,
        "equipment": ["DUMBBELL"],
        "secondary": {},
    },
    {
        "code": "BODYWEIGHT_CALF_RAISE",
        "name": "Standing Bodyweight Calf Raise",
        "primary": "CALVES",
        "movement": "plantar_flexion",
        "difficulty": "beginner",
        "compound": False,
        "min_reps": 12,
        "max_reps": 25,
        "rest": 60,
        "equipment": ["BODYWEIGHT"],
        "secondary": {},
    },
    {
        "code": "MACHINE_CALF_RAISE",
        "name": "Machine Calf Raise",
        "primary": "CALVES",
        "movement": "plantar_flexion",
        "difficulty": "beginner",
        "compound": False,
        "min_reps": 10,
        "max_reps": 20,
        "rest": 75,
        "equipment": ["MACHINE"],
        "secondary": {},
    },

    # =========================
    # CORE
    # =========================
    {
        "code": "CABLE_CRUNCH",
        "name": "Cable Crunch",
        "primary": "ABS",
        "movement": "spinal_flexion",
        "difficulty": "beginner",
        "compound": False,
        "min_reps": 10,
        "max_reps": 20,
        "rest": 75,
        "equipment": ["CABLE"],
        "secondary": {},
    },
    {
        "code": "PLANK",
        "name": "Plank",
        "primary": "ABS",
        "movement": "isometric_core",
        "difficulty": "beginner",
        "compound": False,
        "min_reps": 1,
        "max_reps": 3,
        "rest": 60,
        "equipment": ["BODYWEIGHT"],
        "secondary": {},
    },
    {
        "code": "HANGING_LEG_RAISE",
        "name": "Hanging Leg Raise",
        "primary": "ABS",
        "movement": "hip_flexion_core",
        "difficulty": "intermediate",
        "compound": False,
        "min_reps": 8,
        "max_reps": 15,
        "rest": 90,
        "equipment": ["PULLUP_BAR"],
        "secondary": {},
    },
]


def seed_exercises():
    db = SessionLocal()

    try:
        muscle_groups = {
            muscle.code: muscle
            for muscle in db.scalars(
                select(MuscleGroup)
            ).all()
        }

        equipment_map = {
            equipment.code: equipment
            for equipment in db.scalars(
                select(Equipment)
            ).all()
        }

        for data in EXERCISES:
            primary = muscle_groups.get(
                data["primary"]
            )

            if primary is None:
                raise ValueError(
                    f"Unknown muscle group: {data['primary']}"
                )

            exercise = db.scalar(
                select(Exercise).where(
                    Exercise.code == data["code"]
                )
            )

            if exercise is None:
                exercise = Exercise(
                    code=data["code"],
                    primary_muscle_id=primary.id,
                    name=data["name"],
                    movement_pattern=data["movement"],
                    difficulty=data["difficulty"],
                    is_compound=data["compound"],
                    default_min_reps=data["min_reps"],
                    default_max_reps=data["max_reps"],
                    default_rest_seconds=data["rest"],
                    active=True,
                )

                db.add(exercise)
                db.flush()

            else:
                exercise.name = data["name"]
                exercise.primary_muscle_id = primary.id
                exercise.movement_pattern = data["movement"]
                exercise.difficulty = data["difficulty"]
                exercise.is_compound = data["compound"]
                exercise.default_min_reps = data["min_reps"]
                exercise.default_max_reps = data["max_reps"]
                exercise.default_rest_seconds = data["rest"]
                exercise.active = True

            db.execute(
                delete(ExerciseEquipment).where(
                    ExerciseEquipment.exercise_id
                    == exercise.id
                )
            )

            db.execute(
                delete(ExerciseSecondaryMuscle).where(
                    ExerciseSecondaryMuscle.exercise_id
                    == exercise.id
                )
            )

            for equipment_code in data["equipment"]:
                equipment = equipment_map.get(
                    equipment_code
                )

                if equipment is None:
                    raise ValueError(
                        f"Unknown equipment: {equipment_code}"
                    )

                db.add(
                    ExerciseEquipment(
                        exercise_id=exercise.id,
                        equipment_id=equipment.id,
                    )
                )

            for muscle_code, weight in data[
                "secondary"
            ].items():
                muscle = muscle_groups.get(
                    muscle_code
                )

                if muscle is None:
                    raise ValueError(
                        f"Unknown secondary muscle: {muscle_code}"
                    )

                db.add(
                    ExerciseSecondaryMuscle(
                        exercise_id=exercise.id,
                        muscle_group_id=muscle.id,
                        contribution_weight=weight,
                    )
                )

        db.commit()

    except Exception:
        db.rollback()
        raise

    finally:
        db.close()


if __name__ == "__main__":
    seed_exercises()