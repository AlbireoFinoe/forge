import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/adaptation_models.dart';
import '../data/adaptation_repository.dart';

final adaptationRepositoryProvider = Provider<AdaptationRepository>((ref) {
  final apiClient = ref.read(apiClientProvider);

  return AdaptationRepository(apiClient);
});

final adaptationOverviewProvider = FutureProvider<AdaptationOverviewData>((
  ref,
) async {
  final repository = ref.read(adaptationRepositoryProvider);

  return repository.getOverview();
});

final exerciseAdaptationProvider =
    FutureProvider.family<AdaptationRecommendationData, String>((
      ref,
      exerciseCode,
    ) async {
      final repository = ref.read(adaptationRepositoryProvider);

      return repository.getExerciseRecommendation(exerciseCode);
    });
