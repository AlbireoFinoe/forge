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
          ? AppBar(title: const Text('Training Schedule'))
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!widget.settingsMode) ...[
                    const ForgeOnboardingProgress(currentStep: 2),
                    const SizedBox(height: ForgeSpacing.xxl),
                  ],

                  Text(
                    'Build your training schedule',
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tell FORGE when and how long you usually train.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 32),

                  Text(
                    'Training days',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    selectedCount == 0
                        ? 'Select at least one day.'
                        : '$selectedCount ${selectedCount == 1 ? 'day' : 'days'} per week',
                  ),
                  const SizedBox(height: 16),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final day in weekdays)
                        FilterChip(
                          label: Text(
                            day.shortLabel,
                            style: TextStyle(
                              color: _selectedDays.contains(day.value)
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurface,
                              fontWeight: _selectedDays.contains(day.value)
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                          selected: _selectedDays.contains(day.value),
                          selectedColor: Theme.of(context).colorScheme.primary,
                          checkmarkColor: Theme.of(context)
                              .colorScheme
                              .onPrimary,
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

                  const SizedBox(height: 32),

                  Text(
                    'Session duration',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text('$_sessionDurationMinutes minutes'),
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

                  const SizedBox(height: 16),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('No dedicated leg day'),
                    subtitle: const Text(
                      'Keep leg training integrated into other sessions instead of using a separate leg day.',
                    ),
                    value: _noDedicatedLegDay,
                    onChanged: _isSubmitting
                        ? null
                        : (value) {
                            setState(() {
                              _noDedicatedLegDay = value;
                            });
                          },
                  ),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Arm specialization'),
                    subtitle: const Text(
                      'Give additional training emphasis to biceps and triceps.',
                    ),
                    value: _armSpecialization,
                    onChanged: _isSubmitting
                        ? null
                        : (value) {
                            setState(() {
                              _armSpecialization = value;
                            });
                          },
                  ),

                  const SizedBox(height: 24),

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
                              widget.settingsMode ? 'Save Changes' : 'Continue',
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
