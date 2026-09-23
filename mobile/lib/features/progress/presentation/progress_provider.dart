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
