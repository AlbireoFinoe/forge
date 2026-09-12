import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/muscle_models.dart';
import '../data/muscle_repository.dart';
import 'muscle_priority_controller.dart';

class MusclePriorityScreen extends ConsumerStatefulWidget {
  const MusclePriorityScreen({required this.data, super.key});

  final MusclePrioritiesData data;

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
                    'Set your muscle priorities',
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tell FORGE which muscle groups should receive more or less training emphasis.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Normal is recommended for most muscles. Use High for muscles you want to prioritize, and Maintenance for muscles you only want to maintain.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),

                  for (final entry in grouped.entries) ...[
                    Text(
                      entry.key,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),

                    for (final muscle in entry.value)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _MusclePriorityCard(
                          muscle: muscle,
                          priority:
                              _priorities[muscle.code] ??
                              MusclePriorityLevel.normal,
                          enabled: !_isSubmitting,
                          onChanged: (priority) {
                            setState(() {
                              _priorities[muscle.code] = priority;
                            });
                          },
                        ),
                      ),

                    const SizedBox(height: 12),
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
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              muscle.name,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in MusclePriorityLevel.values)
                  ChoiceChip(
                    label: Text(option.label),
                    selected: priority == option,
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
      ),
    );
  }
}
