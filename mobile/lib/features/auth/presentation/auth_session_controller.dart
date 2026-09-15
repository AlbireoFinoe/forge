import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/auth_repository.dart';
import '../data/auth_user.dart';
import '../../onboarding/presentation/onboarding_controller.dart';
import '../../muscles/presentation/muscle_priority_controller.dart';
import '../../equipment/presentation/equipment_controller.dart';
import '../../sports/presentation/sport_controller.dart';
import '../../profile/presentation/profile_controller.dart';

enum AuthSessionStatus { authenticated, unauthenticated }

class AuthSessionState {
  const AuthSessionState._({required this.status, this.user});

  const AuthSessionState.authenticated(AuthUser user)
    : this._(status: AuthSessionStatus.authenticated, user: user);

  const AuthSessionState.unauthenticated()
    : this._(status: AuthSessionStatus.unauthenticated);

  final AuthSessionStatus status;
  final AuthUser? user;

  bool get isAuthenticated => status == AuthSessionStatus.authenticated;
}

class AuthSessionController extends AsyncNotifier<AuthSessionState> {
  AuthRepository get _authRepository => ref.read(authRepositoryProvider);

  @override
  Future<AuthSessionState> build() async {
    final hasToken = await _authRepository.hasStoredToken();

    if (!hasToken) {
      return const AuthSessionState.unauthenticated();
    }

    try {
      final user = await _authRepository.getCurrentUser();

      return AuthSessionState.authenticated(user);
    } on AuthException catch (error) {
      if (error.isUnauthorized) {
        await _authRepository.logout();

        return const AuthSessionState.unauthenticated();
      }

      rethrow;
    }
  }

  Future<void> login({required String email, required String password}) async {
    final user = await _authRepository.login(email: email, password: password);

    ref.invalidate(onboardingControllerProvider);
    ref.invalidate(musclePriorityControllerProvider);
    ref.invalidate(equipmentControllerProvider);
    ref.invalidate(sportControllerProvider);
    ref.invalidate(profileControllerProvider);

    state = AsyncData(AuthSessionState.authenticated(user));
  }

  Future<void> registerAndLogin({
    required String email,
    required String password,
  }) async {
    await _authRepository.register(email: email, password: password);

    final user = await _authRepository.login(email: email, password: password);

    ref.invalidate(onboardingControllerProvider);
    ref.invalidate(musclePriorityControllerProvider);
    ref.invalidate(sportControllerProvider);
    ref.invalidate(profileControllerProvider);

    state = AsyncData(AuthSessionState.authenticated(user));
  }

  Future<void> logout() async {
    state = const AsyncLoading();

    await _authRepository.logout();

    ref.invalidate(onboardingControllerProvider);
    ref.invalidate(musclePriorityControllerProvider);
    ref.invalidate(sportControllerProvider);
    ref.invalidate(profileControllerProvider);

    state = const AsyncData(AuthSessionState.unauthenticated());
  }

  Future<void> refreshSession() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final user = await _authRepository.getCurrentUser();

      return AuthSessionState.authenticated(user);
    });
  }
}

final authSessionControllerProvider =
    AsyncNotifierProvider<AuthSessionController, AuthSessionState>(
      AuthSessionController.new,
    );
