import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/exercise_models.dart';
import '../data/exercise_repository.dart';

final exerciseRepositoryProvider = Provider<ExerciseRepository>((ref) {
  final apiClient = ref.read(apiClientProvider);

  return ExerciseRepository(apiClient);
});

final exerciseDetailProvider =
    FutureProvider.family<ExerciseDetailData, String>((ref, exerciseId) async {
      final repository = ref.read(exerciseRepositoryProvider);

      return repository.getExerciseById(exerciseId);
    });
