import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/equipment_models.dart';
import '../data/equipment_repository.dart';

final equipmentRepositoryProvider = Provider<EquipmentRepository>((ref) {
  final apiClient = ref.read(apiClientProvider);

  return EquipmentRepository(apiClient);
});

class EquipmentController extends AsyncNotifier<EquipmentSelectionData> {
  EquipmentRepository get _repository => ref.read(equipmentRepositoryProvider);

  @override
  Future<EquipmentSelectionData> build() async {
    final catalog = await _repository.getEquipmentCatalog();

    final selected = await _repository.getUserEquipment();

    return EquipmentSelectionData(
      catalog: catalog,
      selectedCodes: {for (final equipment in selected) equipment.code},
    );
  }

  Future<void> saveSelection(Set<String> equipmentCodes) async {
    final current = state.value ?? await build();

    final saved = await _repository.updateUserEquipment(equipmentCodes);

    state = AsyncData(
      EquipmentSelectionData(
        catalog: current.catalog,
        selectedCodes: {for (final equipment in saved) equipment.code},
      ),
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(build);
  }
}

final equipmentControllerProvider =
    AsyncNotifierProvider<EquipmentController, EquipmentSelectionData>(
      EquipmentController.new,
    );
