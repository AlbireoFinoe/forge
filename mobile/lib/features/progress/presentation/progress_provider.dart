import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/progress_models.dart';
import '../data/progress_repository.dart';

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  final apiClient = ref.read(apiClientProvider);

  return ProgressRepository(apiClient);
});

final progressOverviewProvider = FutureProvider<ProgressOverviewData>((
  ref,
) async {
  final repository = ref.read(progressRepositoryProvider);

  return repository.getOverview();
});

final exerciseProgressProvider =
    FutureProvider.family<ExerciseProgressData, String>((
      ref,
      exerciseCode,
    ) async {
      final repository = ref.read(progressRepositoryProvider);

      return repository.getExerciseProgress(exerciseCode);
    });

final exerciseProgressHistoryProvider =
    FutureProvider.family<List<ExerciseHistoryItemData>, String>((
      ref,
      exerciseCode,
    ) async {
      final repository = ref.read(progressRepositoryProvider);

      return repository.getExerciseHistory(exerciseCode);
    });
