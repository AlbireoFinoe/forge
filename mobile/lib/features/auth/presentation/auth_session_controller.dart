import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/auth/session_expiry_notifier.dart';
import '../data/auth_repository.dart';
import '../data/auth_user.dart';
import '../../onboarding/presentation/onboarding_controller.dart';
import '../../muscles/presentation/muscle_priority_controller.dart';
import '../../equipment/presentation/equipment_controller.dart';
import '../../sports/presentation/sport_controller.dart';
import '../../profile/presentation/profile_controller.dart';
import '../../program/presentation/program_controller.dart';
import '../../workout/presentation/workout_controller.dart';

enum AuthSessionStatus { authenticated, unauthenticated }

class AuthSessionState {
  const AuthSessionState._({required this.status, this.user, this.notice});

  const AuthSessionState.authenticated(AuthUser user)
    : this._(status: AuthSessionStatus.authenticated, user: user);

  const AuthSessionState.unauthenticated({String? notice})
    : this._(status: AuthSessionStatus.unauthenticated, notice: notice);

  final AuthSessionStatus status;
  final AuthUser? user;
  final String? notice;

  bool get isAuthenticated => status == AuthSessionStatus.authenticated;
}

class AuthSessionController extends AsyncNotifier<AuthSessionState> {
  static const String _sessionExpiredMessage =
      'Your session has expired. Please sign in again.';

  AuthRepository get _authRepository => ref.read(authRepositoryProvider);

  @override
  Future<AuthSessionState> build() async {
    ref.listen<int>(sessionExpiryProvider, (previous, next) {
      if (previous != null && previous != next) {
        _handleSessionExpired();
      }
    });

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

        return const AuthSessionState.unauthenticated(
          notice: _sessionExpiredMessage,
        );
      }

      rethrow;
    }
  }

  Future<void> login({required String email, required String password}) async {
    final user = await _authRepository.login(email: email, password: password);

    _invalidateUserState();

    state = AsyncData(AuthSessionState.authenticated(user));
  }

  Future<void> registerAndLogin({
    required String email,
    required String password,
  }) async {
    await _authRepository.register(email: email, password: password);

    final user = await _authRepository.login(email: email, password: password);

    _invalidateUserState();

    state = AsyncData(AuthSessionState.authenticated(user));
  }

  Future<void> logout() async {
    state = const AsyncLoading();

    await _authRepository.logout();

    _invalidateUserState();

    state = const AsyncData(AuthSessionState.unauthenticated());
  }

  Future<void> refreshSession() async {
    state = const AsyncLoading();

    try {
      final user = await _authRepository.getCurrentUser();

      state = AsyncData(AuthSessionState.authenticated(user));
    } on AuthException catch (error, stackTrace) {
      if (error.isUnauthorized) {
        await _authRepository.logout();

        _invalidateUserState();

        state = const AsyncData(
          AuthSessionState.unauthenticated(notice: _sessionExpiredMessage),
        );

        return;
      }

      state = AsyncError(error, stackTrace);
    }
  }

  void _handleSessionExpired() {
    final current = state.value;

    if (current == null || !current.isAuthenticated) {
      return;
    }

    _invalidateUserState();

    state = const AsyncData(
      AuthSessionState.unauthenticated(notice: _sessionExpiredMessage),
    );

    unawaited(_authRepository.logout());
  }

  void _invalidateUserState() {
    ref.invalidate(onboardingControllerProvider);
    ref.invalidate(musclePriorityControllerProvider);
    ref.invalidate(equipmentControllerProvider);
    ref.invalidate(sportControllerProvider);
    ref.invalidate(profileControllerProvider);
    ref.invalidate(programControllerProvider);
    ref.invalidate(workoutControllerProvider);
  }
}

final authSessionControllerProvider =
    AsyncNotifierProvider<AuthSessionController, AuthSessionState>(
      AuthSessionController.new,
    );
