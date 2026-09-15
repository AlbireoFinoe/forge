import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_user.dart';
import 'goal_selection_screen.dart';
import 'onboarding_controller.dart';
import 'training_preferences_screen.dart';
import '../../muscles/presentation/muscle_priority_gate.dart';
import '../../equipment/presentation/equipment_gate.dart';
import '../../auth/presentation/auth_session_controller.dart';
import '../../sports/presentation/sports_gate.dart';
import '../../profile/presentation/profile_gate.dart';

class OnboardingGate extends ConsumerWidget {
  const OnboardingGate({required this.user, super.key});

  final AuthUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarding = ref.watch(onboardingControllerProvider);

    return onboarding.when(
      loading: () {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
      error: (error, stackTrace) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 48),
                  const SizedBox(height: 16),
                  const Text('Could not load your training setup.'),
                  const SizedBox(height: 8),
                  Text(error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      ref.read(onboardingControllerProvider.notifier).refresh();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      data: (data) {
        if (!data.hasGoal) {
          return const GoalSelectionScreen();
        }

        if (!data.hasTrainingPreferences) {
          return const TrainingPreferencesScreen();
        }

        return ProfileGate(
          onComplete: MusclePriorityGate(
            onComplete: EquipmentGate(
              onComplete: SportsGate(
                configured: data.trainingPreferences!.sportsConfigured,
                onComplete: Scaffold(
                  appBar: AppBar(
                    title: const Text('FORGE'),
                    actions: [
                      IconButton(
                        onPressed: () {
                          ref
                              .read(authSessionControllerProvider.notifier)
                              .logout();
                        },
                        tooltip: 'Logout',
                        icon: const Icon(Icons.logout),
                      ),
                    ],
                  ),
                  body: const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline, size: 64),
                          SizedBox(height: 16),
                          Text('Training setup complete.'),
                          SizedBox(height: 8),
                          Text(
                            'FORGE is ready for the next step.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
