class EquipmentData {
  const EquipmentData({
    required this.id,
    required this.code,
    required this.name,
  });

  final String id;
  final String code;
  final String name;

  bool get isFullGym => code == 'FULL_GYM';

  factory EquipmentData.fromJson(Map<String, dynamic> json) {
    return EquipmentData(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
    );
  }
}

class EquipmentSelectionData {
  const EquipmentSelectionData({
    required this.catalog,
    required this.selectedCodes,
  });

  final List<EquipmentData> catalog;
  final Set<String> selectedCodes;

  bool get isConfigured => selectedCodes.isNotEmpty;

  bool get hasFullGym => selectedCodes.contains('FULL_GYM');

  bool isSelected(String code) {
    return selectedCodes.contains(code);
  }
}
