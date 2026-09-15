import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/profile_models.dart';
import '../data/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final apiClient = ref.read(apiClientProvider);

  return ProfileRepository(apiClient);
});

class ProfileController extends AsyncNotifier<ProfileData> {
  ProfileRepository get _repository => ref.read(profileRepositoryProvider);

  @override
  Future<ProfileData> build() {
    return _repository.getProfile();
  }

  Future<void> setExperienceLevel(TrainingExperience experience) async {
    final updated = await _repository.updateExperienceLevel(experience);

    state = AsyncData(updated);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(_repository.getProfile);
  }
}

final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, ProfileData>(
      ProfileController.new,
    );
