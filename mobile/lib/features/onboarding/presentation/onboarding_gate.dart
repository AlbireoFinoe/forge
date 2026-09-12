import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_user.dart';
import 'goal_selection_screen.dart';
import 'onboarding_controller.dart';
import 'training_preferences_screen.dart';
import '../../muscles/presentation/muscle_priority_gate.dart';

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

        return MusclePriorityGate(
          onComplete: Scaffold(
            appBar: AppBar(title: const Text('FORGE')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fitness_center, size: 56),
                    const SizedBox(height: 16),
                    Text(
                      'Equipment',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Muscle priorities are saved. Equipment selection is the next onboarding step.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
