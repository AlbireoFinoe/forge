import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/exercise_models.dart';
import '../data/exercise_repository.dart';
import '../data/exercise_summary_data.dart';

final exerciseRepositoryProvider = Provider<ExerciseRepository>((ref) {
  final apiClient = ref.read(apiClientProvider);

  return ExerciseRepository(apiClient);
});

final exerciseLibraryProvider = FutureProvider<List<ExerciseSummaryData>>((
  ref,
) async {
  final repository = ref.read(exerciseRepositoryProvider);

  return repository.getExercises();
});

final exercisesByMuscleProvider =
    FutureProvider.family<List<ExerciseSummaryData>, String>((
      ref,
      muscleCode,
    ) async {
      final repository = ref.read(exerciseRepositoryProvider);

      return repository.getExercises(muscle: muscleCode);
    });

final exerciseDetailProvider =
    FutureProvider.family<ExerciseDetailData, String>((ref, exerciseId) async {
      final repository = ref.read(exerciseRepositoryProvider);

      return repository.getExerciseById(exerciseId);
    });
