import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/forge_theme.dart';
import '../../../core/widgets/forge_onboarding_progress.dart';

import '../data/profile_models.dart';
import '../data/profile_repository.dart';
import 'profile_controller.dart';

class ExperienceLevelScreen extends ConsumerStatefulWidget {
  const ExperienceLevelScreen({
    required this.profile,
    this.settingsMode = false,
    super.key,
  });

  final ProfileData profile;
  final bool settingsMode;

  @override
  ConsumerState<ExperienceLevelScreen> createState() =>
      _ExperienceLevelScreenState();
}

class _ExperienceLevelScreenState extends ConsumerState<ExperienceLevelScreen> {
  TrainingExperience? _selected;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    _selected = widget.profile.experienceLevel;
  }

  Future<void> _continue() async {
    final selected = _selected;

    if (selected == null || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ref
          .read(profileControllerProvider.notifier)
          .setExperienceLevel(selected);

      if (widget.settingsMode && mounted) {
        Navigator.of(context).pop(true);
      }
    } on ProfileException catch (error) {
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
          content: Text('Could not save your training experience.'),
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
    return Scaffold(
      appBar: widget.settingsMode
          ? AppBar(title: const Text('EXPERIENCE LEVEL'))
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
                    const ForgeOnboardingProgress(currentStep: 3),
                    const SizedBox(height: ForgeSpacing.xxl),
                  ],

                  if (!widget.settingsMode) ...[
                    Text(
                      'YOUR EXPERIENCE',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                    ),
                    const SizedBox(height: 6),
                  ],

                  Text(
                    'FORGE uses your experience '
                    'level to adjust training volume, '
                    'exercise complexity and overall '
                    'program demands.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: ForgeColors.textSecondary,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: ForgeSpacing.xl),

                  Container(
                    padding: const EdgeInsets.all(ForgeSpacing.lg),
                    decoration: BoxDecoration(
                      color: ForgeColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(ForgeRadius.lg),
                      border: Border.all(color: ForgeColors.outline),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: ForgeColors.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(ForgeRadius.md),
                          ),
                          child: const Icon(
                            Icons.monitor_heart_outlined,
                            color: ForgeColors.primary,
                            size: 22,
                          ),
                        ),

                        const SizedBox(width: ForgeSpacing.md),

                        Expanded(
                          child: Text(
                            'Choose the level that best '
                            'matches your current training '
                            'background, not where you '
                            'want to be.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: ForgeColors.textSecondary,
                                  height: 1.4,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: ForgeSpacing.xl),

                  for (final experience in TrainingExperience.values) ...[
                    _ExperienceCard(
                      experience: experience,
                      selected: _selected == experience,
                      enabled: !_isSubmitting,
                      onTap: () {
                        setState(() {
                          _selected = experience;
                        });
                      },
                    ),

                    const SizedBox(height: ForgeSpacing.md),
                  ],

                  const SizedBox(height: ForgeSpacing.md),

                  FilledButton(
                    onPressed: _selected != null && !_isSubmitting
                        ? _continue
                        : null,
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

class _ExperienceCard extends StatelessWidget {
  const _ExperienceCard({
    required this.experience,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final TrainingExperience experience;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? ForgeColors.primary.withValues(alpha: 0.06)
          : ForgeColors.surface,
      borderRadius: BorderRadius.circular(ForgeRadius.lg),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(ForgeRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(ForgeSpacing.lg),
          decoration: BoxDecoration(
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
                  _experienceIcon(experience),
                  size: 22,
                  color: selected
                      ? ForgeColors.primary
                      : ForgeColors.textSecondary,
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
                            experience.label,
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
                              'SELECTED',
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
                      experience.description,
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

IconData _experienceIcon(TrainingExperience experience) {
  switch (experience) {
    case TrainingExperience.beginner:
      return Icons.spa_outlined;
    case TrainingExperience.intermediate:
      return Icons.trending_up_rounded;
    case TrainingExperience.advanced:
      return Icons.bolt_rounded;
  }
}
