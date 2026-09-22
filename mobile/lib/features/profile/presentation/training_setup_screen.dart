import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/forge_theme.dart';

import '../../equipment/presentation/equipment_controller.dart';
import '../../equipment/presentation/equipment_screen.dart';
import '../../muscles/presentation/muscle_priority_controller.dart';
import '../../muscles/presentation/muscle_priority_screen.dart';
import 'experience_level_screen.dart';
import 'profile_controller.dart';
import '../../onboarding/presentation/goal_selection_screen.dart';
import '../../onboarding/presentation/onboarding_controller.dart';
import '../../onboarding/presentation/training_preferences_screen.dart';

class TrainingSetupScreen extends StatelessWidget {
  const TrainingSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TRAINING SETUP')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          ForgeSpacing.xl,
          ForgeSpacing.lg,
          ForgeSpacing.xl,
          ForgeSpacing.xxl + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Text(
            'TRAINING SETUP',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.4),
          ),

          const SizedBox(height: 6),

          Text(
            'Configure how FORGE builds '
            'your training program.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: ForgeColors.textSecondary),
          ),

          const SizedBox(height: ForgeSpacing.xl),

          const _SetupOverviewCard(),

          const SizedBox(height: ForgeSpacing.xxl),

          const _SetupSectionLabel(label: 'PROGRAM PREFERENCES'),

          const SizedBox(height: ForgeSpacing.md),

          _SetupGroup(
            children: [
              _SetupTile(
                icon: Icons.flag_rounded,
                title: 'Goals',
                subtitle: 'Primary and secondary training goals',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) {
                        return const _GoalSettingsPage();
                      },
                    ),
                  );
                },
              ),

              const _SetupDivider(),

              _SetupTile(
                icon: Icons.calendar_month_rounded,
                title: 'Training Schedule',
                subtitle: 'Training days and session preferences',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) {
                        return const _TrainingScheduleSettingsPage();
                      },
                    ),
                  );
                },
              ),

              const _SetupDivider(),

              _SetupTile(
                icon: Icons.trending_up_rounded,
                title: 'Experience Level',
                subtitle: 'Beginner, intermediate or advanced',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) {
                        return const _ExperienceSettingsPage();
                      },
                    ),
                  );
                },
              ),

              const _SetupDivider(),

              _SetupTile(
                icon: Icons.accessibility_new_rounded,
                title: 'Muscle Priorities',
                subtitle: 'Choose which muscles receive more focus',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) {
                        return const _MusclePrioritySettingsPage();
                      },
                    ),
                  );
                },
              ),

              const _SetupDivider(),

              _SetupTile(
                icon: Icons.fitness_center_rounded,
                title: 'Equipment',
                subtitle: 'Full gym or custom equipment',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) {
                        return const _EquipmentSettingsPage();
                      },
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: ForgeSpacing.xxl),

          const _TrainingSetupNotice(),
        ],
      ),
    );
  }
}

class _GoalSettingsPage extends ConsumerWidget {
  const _GoalSettingsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarding = ref.watch(onboardingControllerProvider);

    return onboarding.when(
      loading: () {
        return const _SettingsLoadingScreen(title: 'Training Goals');
      },
      error: (error, stackTrace) {
        return _SettingsErrorScreen(
          title: 'Training Goals',
          onRetry: () {
            ref.read(onboardingControllerProvider.notifier).refresh();
          },
        );
      },
      data: (data) {
        final goal = data.goal;

        if (goal == null) {
          return const _MissingSettingsScreen(title: 'Training Goals');
        }

        return GoalSelectionScreen(initialGoal: goal, settingsMode: true);
      },
    );
  }
}

class _TrainingScheduleSettingsPage extends ConsumerWidget {
  const _TrainingScheduleSettingsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarding = ref.watch(onboardingControllerProvider);

    return onboarding.when(
      loading: () {
        return const _SettingsLoadingScreen(title: 'Training Schedule');
      },
      error: (error, stackTrace) {
        return _SettingsErrorScreen(
          title: 'Training Schedule',
          onRetry: () {
            ref.read(onboardingControllerProvider.notifier).refresh();
          },
        );
      },
      data: (data) {
        final preferences = data.trainingPreferences;

        if (preferences == null) {
          return const _MissingSettingsScreen(title: 'Training Schedule');
        }

        return TrainingPreferencesScreen(
          initialPreferences: preferences,
          settingsMode: true,
        );
      },
    );
  }
}

class _ExperienceSettingsPage extends ConsumerWidget {
  const _ExperienceSettingsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileControllerProvider);

    return profile.when(
      loading: () {
        return const _SettingsLoadingScreen(title: 'Experience Level');
      },
      error: (error, stackTrace) {
        return _SettingsErrorScreen(
          title: 'Experience Level',
          onRetry: () {
            ref.invalidate(profileControllerProvider);
          },
        );
      },
      data: (data) {
        return ExperienceLevelScreen(profile: data, settingsMode: true);
      },
    );
  }
}

class _MusclePrioritySettingsPage extends ConsumerWidget {
  const _MusclePrioritySettingsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muscles = ref.watch(musclePriorityControllerProvider);

    return muscles.when(
      loading: () {
        return const _SettingsLoadingScreen(title: 'Muscle Priorities');
      },
      error: (error, stackTrace) {
        return _SettingsErrorScreen(
          title: 'Muscle Priorities',
          onRetry: () {
            ref.invalidate(musclePriorityControllerProvider);
          },
        );
      },
      data: (data) {
        return MusclePriorityScreen(data: data, settingsMode: true);
      },
    );
  }
}

class _EquipmentSettingsPage extends ConsumerWidget {
  const _EquipmentSettingsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final equipment = ref.watch(equipmentControllerProvider);

    return equipment.when(
      loading: () {
        return const _SettingsLoadingScreen(title: 'Equipment');
      },
      error: (error, stackTrace) {
        return _SettingsErrorScreen(
          title: 'Equipment',
          onRetry: () {
            ref.invalidate(equipmentControllerProvider);
          },
        );
      },
      data: (data) {
        return EquipmentScreen(data: data, settingsMode: true);
      },
    );
  }
}

class _MissingSettingsScreen extends StatelessWidget {
  const _MissingSettingsScreen({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'These training settings are not available.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _SettingsLoadingScreen extends StatelessWidget {
  const _SettingsLoadingScreen({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _SettingsErrorScreen extends StatelessWidget {
  const _SettingsErrorScreen({required this.title, required this.onRetry});

  final String title;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Could not load your training settings.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupOverviewCard extends StatelessWidget {
  const _SetupOverviewCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ForgeSpacing.lg),
      decoration: BoxDecoration(
        color: ForgeColors.surfaceRaised,
        borderRadius: BorderRadius.circular(ForgeRadius.lg),
        border: Border.all(color: ForgeColors.primary.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ForgeColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(ForgeRadius.md),
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: ForgeColors.primary,
              size: 24,
            ),
          ),

          const SizedBox(width: ForgeSpacing.md),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your training profile',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),

                const SizedBox(height: 5),

                Text(
                  'Goals, schedule, experience, '
                  'muscle priorities, equipment '
                  'and sports all influence how '
                  'FORGE builds your program.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: ForgeColors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupSectionLabel extends StatelessWidget {
  const _SetupSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.8),
    );
  }
}

class _SetupGroup extends StatelessWidget {
  const _SetupGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ForgeColors.surface,
        borderRadius: BorderRadius.circular(ForgeRadius.lg),
        border: Border.all(color: ForgeColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _SetupTile extends StatelessWidget {
  const _SetupTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(ForgeSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ForgeColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(ForgeRadius.md),
                ),
                child: Icon(icon, size: 22, color: ForgeColors.primary),
              ),

              const SizedBox(width: ForgeSpacing.md),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: ForgeColors.textSecondary),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.chevron_right_rounded,
                color: ForgeColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupDivider extends StatelessWidget {
  const _SetupDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 72);
  }
}

class _TrainingSetupNotice extends StatelessWidget {
  const _TrainingSetupNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ForgeSpacing.lg),
      decoration: BoxDecoration(
        color: ForgeColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(ForgeRadius.lg),
        border: Border.all(color: ForgeColors.warning.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ForgeColors.warning.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(ForgeRadius.sm),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: ForgeColors.warning,
              size: 21,
            ),
          ),

          const SizedBox(width: ForgeSpacing.md),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PROGRAM REGENERATION',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: ForgeColors.warning,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  'Changes to your training '
                  'setup do not automatically '
                  'replace your active program. '
                  'FORGE will let you decide '
                  'when to regenerate it.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: ForgeColors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
