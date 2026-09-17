import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/weekdays.dart';
import '../data/sport_models.dart';
import '../data/sport_repository.dart';
import 'sport_controller.dart';

class SportsSetupScreen extends ConsumerWidget {
  const SportsSetupScreen({this.settingsMode = false, super.key});

  final bool settingsMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sports = ref.watch(sportControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sports Activities')),
      body: sports.when(
        loading: () {
          return const Center(child: CircularProgressIndicator());
        },
        error: (error, stackTrace) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 48),
                  const SizedBox(height: 16),
                  const Text('Could not load your sports activities.'),
                  const SizedBox(height: 8),
                  Text(error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      ref.read(sportControllerProvider.notifier).refresh();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        },
        data: (activities) {
          return _SportsSetupContent(
            activities: activities,
            settingsMode: settingsMode,
          );
        },
      ),
    );
  }
}

class _SportsSetupContent extends ConsumerStatefulWidget {
  const _SportsSetupContent({
    required this.activities,
    required this.settingsMode,
  });

  final List<SportActivityData> activities;
  final bool settingsMode;

  @override
  ConsumerState<_SportsSetupContent> createState() =>
      _SportsSetupContentState();
}

class _SportsSetupContentState extends ConsumerState<_SportsSetupContent> {
  bool _isCompleting = false;

  Future<void> _addActivity() async {
    final input = await showDialog<_SportFormResult>(
      context: context,
      builder: (context) {
        return const _SportActivityDialog();
      },
    );

    if (input == null || !mounted) {
      return;
    }

    try {
      await ref
          .read(sportControllerProvider.notifier)
          .addSport(
            sportType: input.sportType,
            dayOfWeek: input.dayOfWeek,
            durationMinutes: input.durationMinutes,
            intensity: input.intensity,
          );
    } on SportException catch (error) {
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
        const SnackBar(content: Text('Could not add the sport activity.')),
      );
    }
  }

  Future<void> _editActivity(SportActivityData activity) async {
    final input = await showDialog<_SportFormResult>(
      context: context,
      builder: (context) {
        return _SportActivityDialog(activity: activity);
      },
    );

    if (input == null || !mounted) {
      return;
    }

    try {
      await ref
          .read(sportControllerProvider.notifier)
          .editSport(
            sportId: activity.id,
            sportType: input.sportType,
            dayOfWeek: input.dayOfWeek,
            durationMinutes: input.durationMinutes,
            intensity: input.intensity,
          );
    } on SportException catch (error) {
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
        const SnackBar(content: Text('Could not update the sport activity.')),
      );
    }
  }

  Future<void> _deleteActivity(SportActivityData activity) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete activity?'),
          content: Text(
            'Remove ${activity.displayName} from your sports schedule?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await ref.read(sportControllerProvider.notifier).removeSport(activity.id);
    } on SportException catch (error) {
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
        const SnackBar(content: Text('Could not delete the sport activity.')),
      );
    }
  }

  Future<void> _completeSetup() async {
    if (_isCompleting) {
      return;
    }

    setState(() {
      _isCompleting = true;
    });

    try {
      await ref.read(sportControllerProvider.notifier).completeSetup();

      if (widget.settingsMode && mounted) {
        Navigator.of(context).pop(true);
      }
    } on SportException catch (error) {
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
        const SnackBar(content: Text('Could not finish sports setup.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCompleting = false;
        });
      }
    }
  }

  Future<void> _confirmNoSports() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('No other sports?'),
          content: const Text(
            'FORGE will build your training plan without additional sports activities. You can add them later.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _completeSetup();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activities = widget.activities;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Do you do any sports outside your gym training?',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sports such as boxing, running, football, or cycling can affect recovery and how FORGE schedules your workouts.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),

                OutlinedButton.icon(
                  onPressed: _isCompleting ? null : _addActivity,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Activity'),
                ),

                const SizedBox(height: 24),

                if (activities.isEmpty) ...[
                  const _EmptySportsState(),
                  const SizedBox(height: 32),
                  OutlinedButton(
                    onPressed: _isCompleting ? null : _confirmNoSports,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text("I don't do other sports"),
                    ),
                  ),
                ] else ...[
                  Text(
                    'Your activities',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),

                  for (final activity in activities)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SportActivityCard(
                        activity: activity,
                        onEdit: _isCompleting
                            ? null
                            : () {
                                _editActivity(activity);
                              },
                        onDelete: _isCompleting
                            ? null
                            : () {
                                _deleteActivity(activity);
                              },
                      ),
                    ),

                  const SizedBox(height: 20),

                  FilledButton(
                    onPressed: _isCompleting ? null : _completeSetup,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: _isCompleting
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptySportsState extends StatelessWidget {
  const _EmptySportsState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.sports,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No sports added yet',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add an activity if you regularly do another sport alongside your gym training.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SportActivityCard extends StatelessWidget {
  const _SportActivityCard({
    required this.activity,
    required this.onEdit,
    required this.onDelete,
  });

  final SportActivityData activity;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(child: Icon(Icons.sports_mma)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    weekdayLabel(activity.dayOfWeek),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    activity.displayName,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${activity.durationMinutes} min • ${activity.intensity.label} intensity',
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit?.call();
                }

                if (value == 'delete') {
                  onDelete?.call();
                }
              },
              itemBuilder: (context) {
                return const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SportActivityDialog extends StatefulWidget {
  const _SportActivityDialog({this.activity});

  final SportActivityData? activity;

  @override
  State<_SportActivityDialog> createState() => _SportActivityDialogState();
}

class _SportActivityDialogState extends State<_SportActivityDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _sportController;
  late final TextEditingController _durationController;

  late int _dayOfWeek;
  late SportIntensity _intensity;

  bool get _isEditing => widget.activity != null;

  @override
  void initState() {
    super.initState();

    final activity = widget.activity;

    _sportController = TextEditingController(text: activity?.displayName ?? '');

    _durationController = TextEditingController(
      text: activity?.durationMinutes.toString() ?? '60',
    );

    _dayOfWeek = activity?.dayOfWeek ?? 1;

    _intensity = activity?.intensity ?? SportIntensity.moderate;
  }

  @override
  void dispose() {
    _sportController.dispose();
    _durationController.dispose();

    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final duration = int.parse(_durationController.text.trim());

    Navigator.of(context).pop(
      _SportFormResult(
        sportType: _sportController.text.trim(),
        dayOfWeek: _dayOfWeek,
        durationMinutes: duration,
        intensity: _intensity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Activity' : 'Add Activity'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _sportController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Sport',
                    hintText: 'e.g. Boxing',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';

                    if (text.length < 2) {
                      return 'Enter a sport name.';
                    }

                    if (text.length > 50) {
                      return 'Maximum 50 characters.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<int>(
                  initialValue: _dayOfWeek,
                  decoration: const InputDecoration(labelText: 'Day'),
                  items: [
                    for (final day in weekdays)
                      DropdownMenuItem(
                        value: day.value,
                        child: Text(day.label),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _dayOfWeek = value;
                      });
                    }
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duration',
                    suffixText: 'minutes',
                  ),
                  validator: (value) {
                    final duration = int.tryParse(value?.trim() ?? '');

                    if (duration == null) {
                      return 'Enter a valid duration.';
                    }

                    if (duration < 10 || duration > 300) {
                      return 'Duration must be 10–300 minutes.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                DropdownButtonFormField<SportIntensity>(
                  initialValue: _intensity,
                  decoration: const InputDecoration(labelText: 'Intensity'),
                  items: [
                    for (final intensity in SportIntensity.values)
                      DropdownMenuItem(
                        value: intensity,
                        child: Text(intensity.label),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _intensity = value;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

class _SportFormResult {
  const _SportFormResult({
    required this.sportType,
    required this.dayOfWeek,
    required this.durationMinutes,
    required this.intensity,
  });

  final String sportType;
  final int dayOfWeek;
  final int durationMinutes;
  final SportIntensity intensity;
}
