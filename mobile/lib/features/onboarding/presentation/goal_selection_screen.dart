import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/onboarding_models.dart';
import '../data/onboarding_repository.dart';
import 'onboarding_controller.dart';

class GoalSelectionScreen extends ConsumerStatefulWidget {
  const GoalSelectionScreen({
    this.initialGoal,
    this.settingsMode = false,
    super.key,
  });

  final GoalData? initialGoal;
  final bool settingsMode;

  @override
  ConsumerState<GoalSelectionScreen> createState() =>
      _GoalSelectionScreenState();
}

class _GoalSelectionScreenState extends ConsumerState<GoalSelectionScreen> {
  TrainingGoal? _primaryGoal;

  final Set<TrainingGoal> _secondaryGoals = {};

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    final initialGoal = widget.initialGoal;

    if (initialGoal != null) {
      _primaryGoal = initialGoal.primaryGoal;
      _secondaryGoals.addAll(initialGoal.secondaryGoals);
    }
  }

  void _selectPrimaryGoal(TrainingGoal goal) {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _primaryGoal = goal;

      // A goal cannot be both primary and secondary.
      _secondaryGoals.remove(goal);
    });
  }

  void _setSecondaryGoal(TrainingGoal goal, bool selected) {
    if (_isSubmitting) {
      return;
    }

    if (selected && _secondaryGoals.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can select up to 2 secondary goals.'),
        ),
      );

      return;
    }

    setState(() {
      if (selected) {
        _secondaryGoals.add(goal);
      } else {
        _secondaryGoals.remove(goal);
      }
    });
  }

  Future<void> _continue() async {
    final primaryGoal = _primaryGoal;

    if (primaryGoal == null || _isSubmitting) {
      return;
    }

    final secondaryGoals = TrainingGoal.values
        .where(_secondaryGoals.contains)
        .toList(growable: false);

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ref
          .read(onboardingControllerProvider.notifier)
          .setGoal(primaryGoal: primaryGoal, secondaryGoals: secondaryGoals);
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
          content: Text('Something went wrong while saving your goals.'),
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
    final primaryGoal = _primaryGoal;

    return Scaffold(
      appBar: widget.settingsMode
          ? AppBar(title: const Text('Training Goals'))
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
                  Text(
                    'What is your main goal?',
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose one primary goal. This will be the main priority of your training program.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 28),

                  for (final goal in TrainingGoal.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PrimaryGoalCard(
                        goal: goal,
                        selected: primaryGoal == goal,
                        onTap: () {
                          _selectPrimaryGoal(goal);
                        },
                      ),
                    ),

                  const SizedBox(height: 24),

                  Text(
                    'Secondary goals',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    primaryGoal == null
                        ? 'Choose your primary goal first.'
                        : 'Optional \u2014 choose up to 2 additional goals.',
                  ),
                  const SizedBox(height: 16),

                  if (primaryGoal != null)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final goal in TrainingGoal.values)
                          if (goal != primaryGoal)
                            FilterChip(
                              label: Text(
                                goal.label,
                                style: TextStyle(
                                  color: _secondaryGoals.contains(goal)
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.onSurface,
                                  fontWeight: _secondaryGoals.contains(goal)
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                              ),
                              selected: _secondaryGoals.contains(goal),
                              selectedColor: Theme.of(context)
                                  .colorScheme
                                  .primary,
                              checkmarkColor: Theme.of(context)
                                  .colorScheme
                                  .onPrimary,
                              onSelected: _isSubmitting
                                  ? null
                                  : (selected) {
                                      _setSecondaryGoal(goal, selected);
                                    },
                            ),
                      ],
                    ),

                  const SizedBox(height: 32),

                  FilledButton(
                    onPressed: primaryGoal == null || _isSubmitting
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

class _PrimaryGoalCard extends StatelessWidget {
  const _PrimaryGoalCard({
    required this.goal,
    required this.selected,
    required this.onTap,
  });

  final TrainingGoal goal;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: selected
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.label,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      goal.description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
