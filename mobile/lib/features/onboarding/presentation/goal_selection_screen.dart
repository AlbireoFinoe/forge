import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/forge_theme.dart';
import '../../../core/widgets/forge_onboarding_progress.dart';

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
          ? AppBar(title: const Text('TRAINING GOALS'))
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
                    const ForgeOnboardingProgress(currentStep: 1),
                    const SizedBox(height: ForgeSpacing.xxl),
                  ],

                  Text(
                    widget.settingsMode ? 'TRAINING GOALS' : 'YOUR GOALS',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Choose what should lead your '
                    'training program. FORGE will '
                    'use this when balancing volume '
                    'and exercise selection.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: ForgeColors.textSecondary,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: ForgeSpacing.xxl),

                  Text(
                    'PRIMARY GOAL',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),

                  const SizedBox(height: ForgeSpacing.sm),

                  Text(
                    'Choose the single goal that '
                    'matters most right now.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: ForgeColors.textSecondary),
                  ),

                  const SizedBox(height: ForgeSpacing.lg),

                  for (final goal in TrainingGoal.values) ...[
                    _PrimaryGoalCard(
                      goal: goal,
                      selected: primaryGoal == goal,
                      onTap: () {
                        _selectPrimaryGoal(goal);
                      },
                    ),

                    const SizedBox(height: ForgeSpacing.md),
                  ],

                  const SizedBox(height: ForgeSpacing.lg),

                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'SECONDARY GOALS',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                        ),
                      ),

                      if (primaryGoal != null)
                        Text(
                          '${_secondaryGoals.length}'
                          ' / 2',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: ForgeColors.textMuted,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                    ],
                  ),

                  const SizedBox(height: ForgeSpacing.sm),

                  Text(
                    primaryGoal == null
                        ? 'Choose your primary goal '
                              'first.'
                        : 'Optional \u2014 choose up '
                              'to 2 additional goals.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: ForgeColors.textSecondary),
                  ),

                  const SizedBox(height: ForgeSpacing.lg),

                  if (primaryGoal != null)
                    Wrap(
                      spacing: ForgeSpacing.sm,
                      runSpacing: ForgeSpacing.sm,
                      children: [
                        for (final goal in TrainingGoal.values)
                          if (goal != primaryGoal)
                            FilterChip(
                              label: Text(
                                goal.label,
                                style: TextStyle(
                                  color: _secondaryGoals.contains(goal)
                                      ? Colors.black
                                      : ForgeColors.textPrimary,
                                  fontWeight: _secondaryGoals.contains(goal)
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                              ),
                              selected: _secondaryGoals.contains(goal),
                              selectedColor: ForgeColors.primary,
                              backgroundColor: ForgeColors.surface,
                              checkmarkColor: Colors.black,
                              side: BorderSide(
                                color: _secondaryGoals.contains(goal)
                                    ? ForgeColors.primary
                                    : ForgeColors.outline,
                              ),
                              onSelected: _isSubmitting
                                  ? null
                                  : (selected) {
                                      _setSecondaryGoal(goal, selected);
                                    },
                            ),
                      ],
                    ),

                  const SizedBox(height: ForgeSpacing.xxl),

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
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(ForgeRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ForgeRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(ForgeSpacing.lg),
          decoration: BoxDecoration(
            color: selected
                ? ForgeColors.primary.withValues(alpha: 0.06)
                : ForgeColors.surface,
            borderRadius: BorderRadius.circular(ForgeRadius.lg),
            border: Border.all(
              color: selected ? ForgeColors.primary : ForgeColors.outline,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? ForgeColors.primary.withValues(alpha: 0.12)
                      : ForgeColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(ForgeRadius.md),
                ),
                child: Icon(
                  selected ? Icons.check_rounded : Icons.flag_outlined,
                  color: selected
                      ? ForgeColors.primary
                      : ForgeColors.textSecondary,
                  size: 22,
                ),
              ),

              const SizedBox(width: ForgeSpacing.md),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            goal.label,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),

                        if (selected)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: ForgeColors.primary.withValues(
                                alpha: 0.10,
                              ),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              'PRIMARY',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: ForgeColors.primary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 9,
                                  ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    Text(
                      goal.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: ForgeColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? ForgeColors.primary : ForgeColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
