import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/forge_theme.dart';
import '../../../core/widgets/forge_onboarding_progress.dart';

import '../data/muscle_models.dart';
import '../data/muscle_repository.dart';
import 'muscle_priority_controller.dart';

class MusclePriorityScreen extends ConsumerStatefulWidget {
  const MusclePriorityScreen({
    required this.data,
    this.settingsMode = false,
    super.key,
  });

  final MusclePrioritiesData data;
  final bool settingsMode;

  @override
  ConsumerState<MusclePriorityScreen> createState() =>
      _MusclePriorityScreenState();
}

class _MusclePriorityScreenState extends ConsumerState<MusclePriorityScreen> {
  late final Map<String, MusclePriorityLevel> _priorities;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    _priorities = {
      for (final muscle in widget.data.muscleGroups)
        muscle.code: widget.data.priorityFor(muscle.code),
    };
  }

  Future<void> _continue() async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ref
          .read(musclePriorityControllerProvider.notifier)
          .savePriorities(_priorities);

      if (widget.settingsMode && mounted) {
        Navigator.of(context).pop(true);
      }
    } on MuscleException catch (error) {
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
            'Something went wrong while saving your muscle priorities.',
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
    final grouped = <String, List<MuscleGroupData>>{};

    for (final muscle in widget.data.muscleGroups) {
      grouped.putIfAbsent(muscle.region, () => []).add(muscle);
    }

    return Scaffold(
      appBar: widget.settingsMode
          ? AppBar(title: const Text('MUSCLE PRIORITIES'))
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
                    const ForgeOnboardingProgress(currentStep: 4),
                    const SizedBox(height: ForgeSpacing.xxl),
                  ],

                  if (!widget.settingsMode) ...[
                    Text(
                      'MUSCLE PRIORITIES',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                    ),
                    const SizedBox(height: 6),
                  ],

                  Text(
                    'Tell FORGE where you want '
                    'more or less training '
                    'emphasis.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: ForgeColors.textSecondary,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: ForgeSpacing.xl),

                  const _PriorityGuide(),

                  const SizedBox(height: ForgeSpacing.xxl),

                  for (final entry in grouped.entries) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _formatRegionLabel(entry.key).toUpperCase(),
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                          ),
                        ),

                        Text(
                          '${entry.value.length} '
                          '${entry.value.length == 1 ? 'MUSCLE' : 'MUSCLES'}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: ForgeColors.textMuted,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),

                    const SizedBox(height: ForgeSpacing.md),

                    for (
                      var index = 0;
                      index < entry.value.length;
                      index++
                    ) ...[
                      _MusclePriorityCard(
                        muscle: entry.value[index],
                        priority:
                            _priorities[entry.value[index].code] ??
                            MusclePriorityLevel.normal,
                        enabled: !_isSubmitting,
                        onChanged: (priority) {
                          setState(() {
                            _priorities[entry.value[index].code] = priority;
                          });
                        },
                      ),

                      if (index < entry.value.length - 1)
                        const SizedBox(height: ForgeSpacing.md),
                    ],

                    const SizedBox(height: ForgeSpacing.xxl),
                  ],

                  FilledButton(
                    onPressed: _isSubmitting ? null : _continue,
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

class _PriorityGuide extends StatelessWidget {
  const _PriorityGuide();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ForgeSpacing.lg),
      decoration: BoxDecoration(
        color: ForgeColors.surfaceRaised,
        borderRadius: BorderRadius.circular(ForgeRadius.lg),
        border: Border.all(color: ForgeColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ForgeColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(ForgeRadius.md),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: ForgeColors.primary,
                  size: 21,
                ),
              ),

              const SizedBox(width: ForgeSpacing.md),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HOW PRIORITY WORKS',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Normal is recommended '
                      'for most muscles.',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: ForgeColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: ForgeSpacing.lg),

          const _PriorityGuideRow(
            label: 'HIGH',
            description: 'More training emphasis',
            icon: Icons.keyboard_arrow_up_rounded,
          ),

          const SizedBox(height: ForgeSpacing.md),

          const _PriorityGuideRow(
            label: 'NORMAL',
            description: 'Balanced development',
            icon: Icons.horizontal_rule_rounded,
          ),

          const SizedBox(height: ForgeSpacing.md),

          const _PriorityGuideRow(
            label: 'MAINTENANCE',
            description: 'Enough work to maintain',
            icon: Icons.keyboard_arrow_down_rounded,
          ),
        ],
      ),
    );
  }
}

class _PriorityGuideRow extends StatelessWidget {
  const _PriorityGuideRow({
    required this.label,
    required this.description,
    required this.icon,
  });

  final String label;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ForgeColors.surface,
            borderRadius: BorderRadius.circular(ForgeRadius.sm),
          ),
          child: Icon(icon, size: 17, color: ForgeColors.primary),
        ),

        const SizedBox(width: ForgeSpacing.md),

        SizedBox(
          width: 104,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.5),
          ),
        ),

        Expanded(
          child: Text(
            description,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: ForgeColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _MusclePriorityCard extends StatelessWidget {
  const _MusclePriorityCard({
    required this.muscle,
    required this.priority,
    required this.enabled,
    required this.onChanged,
  });

  final MuscleGroupData muscle;
  final MusclePriorityLevel priority;
  final bool enabled;
  final ValueChanged<MusclePriorityLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ForgeSpacing.lg),
      decoration: BoxDecoration(
        color: ForgeColors.surface,
        borderRadius: BorderRadius.circular(ForgeRadius.lg),
        border: Border.all(color: ForgeColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ForgeColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(ForgeRadius.sm),
                ),
                child: const Icon(
                  Icons.fitness_center_rounded,
                  size: 19,
                  color: ForgeColors.textSecondary,
                ),
              ),

              const SizedBox(width: ForgeSpacing.md),

              Expanded(
                child: Text(
                  muscle.name,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),

              Text(
                priority.label.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: ForgeColors.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 9,
                ),
              ),
            ],
          ),

          const SizedBox(height: ForgeSpacing.lg),

          Wrap(
            spacing: ForgeSpacing.sm,
            runSpacing: ForgeSpacing.sm,
            children: [
              for (final option in MusclePriorityLevel.values)
                ChoiceChip(
                  label: Text(
                    option.label,
                    style: TextStyle(
                      color: priority == option
                          ? Colors.black
                          : ForgeColors.textPrimary,
                      fontWeight: priority == option
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                  selected: priority == option,
                  selectedColor: ForgeColors.primary,
                  backgroundColor: ForgeColors.surfaceRaised,
                  checkmarkColor: Colors.black,
                  side: BorderSide(
                    color: priority == option
                        ? ForgeColors.primary
                        : ForgeColors.outline,
                  ),
                  onSelected: enabled
                      ? (_) {
                          onChanged(option);
                        }
                      : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatRegionLabel(String value) {
  return value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) {
        if (part.isEmpty) {
          return part;
        }

        return '${part[0].toUpperCase()}'
            '${part.substring(1).toLowerCase()}';
      })
      .join(' ');
}
