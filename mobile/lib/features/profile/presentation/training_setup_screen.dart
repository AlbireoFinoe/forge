import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../equipment/presentation/equipment_controller.dart';
import '../../equipment/presentation/equipment_screen.dart';
import '../../muscles/presentation/muscle_priority_controller.dart';
import '../../muscles/presentation/muscle_priority_screen.dart';
import '../../sports/presentation/sports_setup_screen.dart';
import 'experience_level_screen.dart';
import 'profile_controller.dart';

class TrainingSetupScreen extends StatelessWidget {
  const TrainingSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Training Setup')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Training Setup',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Manage the information FORGE uses to build your training program.',
          ),
          const SizedBox(height: 24),

          const _SetupSectionLabel(label: 'Program Preferences'),
          const SizedBox(height: 8),

          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                const _SetupTile(
                  icon: Icons.flag_outlined,
                  title: 'Goals',
                  subtitle: 'Primary and secondary training goals',
                  enabled: false,
                ),

                const Divider(height: 1),

                const _SetupTile(
                  icon: Icons.calendar_month_outlined,
                  title: 'Training Schedule',
                  subtitle: 'Training days and session preferences',
                  enabled: false,
                ),

                const Divider(height: 1),

                _SetupTile(
                  icon: Icons.trending_up,
                  title: 'Experience Level',
                  subtitle: 'Beginner, intermediate or advanced',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) {
                          return const _ExperienceSettingsPage();
                        },
                      ),
                    );
                  },
                ),

                const Divider(height: 1),

                _SetupTile(
                  icon: Icons.accessibility_new,
                  title: 'Muscle Priorities',
                  subtitle: 'Choose which muscles receive more focus',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) {
                          return const _MusclePrioritySettingsPage();
                        },
                      ),
                    );
                  },
                ),

                const Divider(height: 1),

                _SetupTile(
                  icon: Icons.fitness_center,
                  title: 'Equipment',
                  subtitle: 'Full gym or custom equipment',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) {
                          return const _EquipmentSettingsPage();
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          const _SetupSectionLabel(label: 'Other Activities'),
          const SizedBox(height: 8),

          Card(
            margin: EdgeInsets.zero,
            child: _SetupTile(
              icon: Icons.sports_mma,
              title: 'Sports Activities',
              subtitle: 'Boxing, running and other sports',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) {
                      return const SportsSetupScreen(settingsMode: true);
                    },
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Changes to your training setup do not automatically '
                      'replace your active program. FORGE will let you decide '
                      'when to regenerate it.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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

class _SetupSectionLabel extends StatelessWidget {
  const _SetupSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

class _SetupTile extends StatelessWidget {
  const _SetupTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.enabled = true,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: enabled,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(enabled ? subtitle : '$subtitle • Coming next'),
      trailing: Icon(enabled ? Icons.chevron_right : Icons.lock_outline),
      onTap: enabled ? onTap : null,
    );
  }
}
