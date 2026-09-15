import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/program_models.dart';
import '../data/program_repository.dart';

final programRepositoryProvider = Provider<ProgramRepository>((ref) {
  final apiClient = ref.read(apiClientProvider);

  return ProgramRepository(apiClient);
});

class ProgramState {
  const ProgramState({required this.currentProgram, this.lastGeneration});

  final ProgramDetailData? currentProgram;
  final ProgramGenerateData? lastGeneration;

  bool get hasActiveProgram => currentProgram != null;

  ProgramState copyWith({
    ProgramDetailData? currentProgram,
    ProgramGenerateData? lastGeneration,
  }) {
    return ProgramState(
      currentProgram: currentProgram ?? this.currentProgram,
      lastGeneration: lastGeneration ?? this.lastGeneration,
    );
  }
}

class ProgramController extends AsyncNotifier<ProgramState> {
  ProgramRepository get _repository => ref.read(programRepositoryProvider);

  @override
  Future<ProgramState> build() async {
    final current = await _repository.getCurrentProgram();

    return ProgramState(currentProgram: current);
  }

  Future<ProgramGenerateData> generateProgram() async {
    final generation = await _repository.generateProgram();

    final current = await _repository.getCurrentProgram();

    state = AsyncData(
      ProgramState(currentProgram: current, lastGeneration: generation),
    );

    return generation;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final current = await _repository.getCurrentProgram();

      return ProgramState(currentProgram: current);
    });
  }
}

final programControllerProvider =
    AsyncNotifierProvider<ProgramController, ProgramState>(
      ProgramController.new,
    );
