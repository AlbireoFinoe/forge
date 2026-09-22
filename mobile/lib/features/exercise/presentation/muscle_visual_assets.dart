const Map<String, String> forgeMuscleVisualAssets = {
  'CHEST': 'assets/repdb/muscles/pectoralis-major.webp',
  'BACK': 'assets/repdb/muscles/latissimus-dorsi.webp',

  'FRONT_DELTS': 'assets/repdb/muscles/anterior-deltoid.webp',
  'SIDE_DELTS': 'assets/repdb/muscles/lateral-deltoid.webp',
  'REAR_DELTS': 'assets/repdb/muscles/posterior-deltoid.webp',

  'BICEPS': 'assets/repdb/muscles/biceps-brachii.webp',
  'TRICEPS': 'assets/repdb/muscles/triceps-brachii.webp',
  'FOREARMS': 'assets/repdb/muscles/forearm-flexors.webp',

  'TRAPS': 'assets/repdb/muscles/trapezius.webp',

  'ABS': 'assets/repdb/muscles/rectus-abdominis.webp',

  'QUADS': 'assets/repdb/muscles/quadriceps.webp',
  'HAMSTRINGS': 'assets/repdb/muscles/hamstrings.webp',
  'GLUTES': 'assets/repdb/muscles/gluteus-maximus.webp',
  'CALVES': 'assets/repdb/muscles/gastrocnemius.webp',
};

String? muscleVisualAssetFor(String muscleCode) {
  return forgeMuscleVisualAssets[muscleCode.toUpperCase()];
}
