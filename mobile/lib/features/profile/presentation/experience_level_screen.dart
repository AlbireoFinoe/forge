import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/profile_models.dart';
import '../data/profile_repository.dart';
import 'profile_controller.dart';

class ExperienceLevelScreen extends ConsumerStatefulWidget {
  const ExperienceLevelScreen({required this.profile, super.key});

  final ProfileData profile;

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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "What's your training experience?",
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'FORGE uses your experience level to choose appropriate training volume and exercise difficulty.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 32),

                  for (final experience in TrainingExperience.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _ExperienceCard(
                        experience: experience,
                        selected: _selected == experience,
                        enabled: !_isSubmitting,
                        onTap: () {
                          setState(() {
                            _selected = experience;
                          });
                        },
                      ),
                    ),

                  const SizedBox(height: 16),

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
                          : const Text('Continue'),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: selected
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      experience.label,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(experience.description),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
