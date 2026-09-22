import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/forge_theme.dart';
import '../../../core/widgets/forge_onboarding_progress.dart';

import '../../../core/constants/weekdays.dart';
import '../data/onboarding_repository.dart';
import 'onboarding_controller.dart';
import '../data/onboarding_models.dart';

class TrainingPreferencesScreen extends ConsumerStatefulWidget {
  const TrainingPreferencesScreen({
    this.initialPreferences,
    this.settingsMode = false,
    super.key,
  });

  final TrainingPreferencesData? initialPreferences;

  final bool settingsMode;

  @override
  ConsumerState<TrainingPreferencesScreen> createState() =>
      _TrainingPreferencesScreenState();
}

class _TrainingPreferencesScreenState
    extends ConsumerState<TrainingPreferencesScreen> {
  final Set<int> _selectedDays = {};

  int _sessionDurationMinutes = 75;

  bool _noDedicatedLegDay = false;
  bool _armSpecialization = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    final preferences = widget.initialPreferences;

    if (preferences != null) {
      _selectedDays.addAll(preferences.availableDays);

      _sessionDurationMinutes = preferences.sessionDurationMinutes;

      _noDedicatedLegDay = preferences.noDedicatedLegDay;

      _armSpecialization = preferences.armSpecialization;
    }
  }

  Future<void> _continue() async {
    if (_selectedDays.isEmpty || _isSubmitting) {
      return;
    }

    final selectedDays = _selectedDays.toList()..sort();

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ref
          .read(onboardingControllerProvider.notifier)
          .setTrainingPreferences(
            daysPerWeek: selectedDays.length,
            sessionDurationMinutes: _sessionDurationMinutes,
            availableDays: selectedDays,
            noDedicatedLegDay: _noDedicatedLegDay,
            armSpecialization: _armSpecialization,
          );

      if (widget.settingsMode && mounted) {
        Navigator.of(context).pop(true);
      }
    } on OnboardingException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Something went wrong while saving your training preferences.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedDays.length;

    return Scaffold(
      appBar: widget.settingsMode
          ? AppBar(title: const Text('TRAINING PREFERENCES'))
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            ForgeSpacing.xl,
            ForgeSpacing.lg,
            ForgeSpacing.xl,
            ForgeSpacing.xxl + MediaQuery.paddingOf(context).bottom,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!widget.settingsMode) ...[
                    const ForgeOnboardingProgress(currentStep: 2),
                    const SizedBox(height: ForgeSpacing.xxl),
                  ],

                  if (!widget.settingsMode) ...[
                    Text(
                      'TRAINING PREFERENCES',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                    ),
                    const SizedBox(height: 6),
                  ],

                  Text(
                    'Tell FORGE when and how '
                    'you prefer to train.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: ForgeColors.textSecondary,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: ForgeSpacing.xxl),

                  Text(
                    'SCHEDULE',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),

                  const SizedBox(height: ForgeSpacing.md),

                  Container(
                    padding: const EdgeInsets.all(ForgeSpacing.lg),
                    decoration: BoxDecoration(
                      color: ForgeColors.surface,
                      borderRadius: BorderRadius.circular(ForgeRadius.lg),
                      border: Border.all(color: ForgeColors.outline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Training days',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),

                            Text(
                              selectedCount == 0
                                  ? 'NONE'
                                  : '$selectedCount '
                                        '${selectedCount == 1 ? 'DAY' : 'DAYS'}',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: selectedCount == 0
                                        ? ForgeColors.warning
                                        : ForgeColors.primary,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 5),

                        Text(
                          selectedCount == 0
                              ? 'Select at least '
                                    'one day.'
                              : 'Choose every day '
                                    'you are normally '
                                    'available to train.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: ForgeColors.textSecondary),
                        ),

                        const SizedBox(height: ForgeSpacing.lg),

                        Wrap(
                          spacing: ForgeSpacing.sm,
                          runSpacing: ForgeSpacing.sm,
                          children: [
                            for (final day in weekdays)
                              FilterChip(
                                label: Text(
                                  day.shortLabel,
                                  style: TextStyle(
                                    color: _selectedDays.contains(day.value)
                                        ? Colors.black
                                        : ForgeColors.textPrimary,
                                    fontWeight:
                                        _selectedDays.contains(day.value)
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                ),
                                selected: _selectedDays.contains(day.value),
                                selectedColor: ForgeColors.primary,
                                backgroundColor: ForgeColors.surfaceRaised,
                                checkmarkColor: Colors.black,
                                side: BorderSide(
                                  color: _selectedDays.contains(day.value)
                                      ? ForgeColors.primary
                                      : ForgeColors.outline,
                                ),
                                onSelected: _isSubmitting
                                    ? null
                                    : (selected) {
                                        setState(() {
                                          if (selected) {
                                            _selectedDays.add(day.value);
                                          } else {
                                            _selectedDays.remove(day.value);
                                          }
                                        });
                                      },
                              ),
                          ],
                        ),

                        const SizedBox(height: ForgeSpacing.xl),

                        Container(height: 1, color: ForgeColors.outline),

                        const SizedBox(height: ForgeSpacing.xl),

                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Session duration',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: ForgeColors.primary.withValues(
                                  alpha: 0.10,
                                ),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                '$_sessionDurationMinutes MIN',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: ForgeColors.primary,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 5),

                        Text(
                          'How much time you '
                          'usually have for one '
                          'gym session.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: ForgeColors.textSecondary),
                        ),

                        const SizedBox(height: ForgeSpacing.md),

                        Slider(
                          value: _sessionDurationMinutes.toDouble(),
                          min: 15,
                          max: 240,
                          divisions: 15,
                          label: '$_sessionDurationMinutes min',
                          onChanged: _isSubmitting
                              ? null
                              : (value) {
                                  setState(() {
                                    _sessionDurationMinutes = value.round();
                                  });
                                },
                        ),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '15 MIN',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: ForgeColors.textMuted,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            Text(
                              '240 MIN',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: ForgeColors.textMuted,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: ForgeSpacing.xxl),

                  Text(
                    'PROGRAM PREFERENCES',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    'Optional preferences that '
                    'change how FORGE distributes '
                    'training volume.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: ForgeColors.textSecondary),
                  ),

                  const SizedBox(height: ForgeSpacing.md),

                  _PreferenceSwitchTile(
                    title: 'No dedicated leg day',
                    description:
                        'Keep leg training '
                        'integrated into other '
                        'sessions instead of using '
                        'a separate leg day.',
                    icon: Icons.directions_walk_rounded,
                    value: _noDedicatedLegDay,
                    enabled: !_isSubmitting,
                    onChanged: (value) {
                      setState(() {
                        _noDedicatedLegDay = value;
                      });
                    },
                  ),

                  const SizedBox(height: ForgeSpacing.md),

                  _PreferenceSwitchTile(
                    title: 'Arm specialization',
                    description:
                        'Give additional training '
                        'emphasis to biceps and '
                        'triceps.',
                    icon: Icons.fitness_center_rounded,
                    value: _armSpecialization,
                    enabled: !_isSubmitting,
                    onChanged: (value) {
                      setState(() {
                        _armSpecialization = value;
                      });
                    },
                  ),

                  const SizedBox(height: ForgeSpacing.xxl),

                  FilledButton(
                    onPressed: _selectedDays.isEmpty || _isSubmitting
                        ? null
                        : _continue,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              widget.settingsMode ? 'SAVE CHANGES' : 'CONTINUE',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreferenceSwitchTile extends StatelessWidget {
  const _PreferenceSwitchTile({
    required this.title,
    required this.description,
    required this.icon,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: value
            ? ForgeColors.primary.withValues(alpha: 0.05)
            : ForgeColors.surface,
        borderRadius: BorderRadius.circular(ForgeRadius.lg),
        border: Border.all(
          color: value
              ? ForgeColors.primary.withValues(alpha: 0.35)
              : ForgeColors.outline,
        ),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ForgeSpacing.lg,
          vertical: ForgeSpacing.sm,
        ),
        secondary: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: value
                ? ForgeColors.primary.withValues(alpha: 0.12)
                : ForgeColors.surfaceRaised,
            borderRadius: BorderRadius.circular(ForgeRadius.md),
          ),
          child: Icon(
            icon,
            size: 21,
            color: value ? ForgeColors.primary : ForgeColors.textSecondary,
          ),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            description,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: ForgeColors.textSecondary, height: 1.35),
          ),
        ),
        value: value,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}
