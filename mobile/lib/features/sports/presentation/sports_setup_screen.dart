import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/weekdays.dart';
import '../../../core/theme/forge_theme.dart';
import '../../../core/widgets/forge_onboarding_progress.dart';
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
      appBar: settingsMode
          ? AppBar(title: const Text('Sports Activities'))
          : null,
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
                  const ForgeOnboardingProgress(currentStep: 6),
                  const SizedBox(height: ForgeSpacing.xxl),
                ],

                Text(
                  'SPORTS ACTIVITIES',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'Add sports you regularly do '
                  'outside your gym training.',
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: ForgeColors.textSecondary),
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
                          Icons.sports_mma_rounded,
                          color: ForgeColors.primary,
                          size: 22,
                        ),
                      ),

                      const SizedBox(width: ForgeSpacing.md),

                      Expanded(
                        child: Text(
                          'Boxing, running, football, '
                          'cycling and similar activities '
                          'can affect recovery and how '
                          'FORGE schedules gym sessions.',
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

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isCompleting ? null : _addActivity,
                    icon: const Icon(Icons.add_rounded),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('ADD ACTIVITY'),
                    ),
                  ),
                ),

                const SizedBox(height: ForgeSpacing.xxl),

                if (activities.isEmpty) ...[
                  const _EmptySportsState(),

                  const SizedBox(height: ForgeSpacing.xl),

                  TextButton(
                    onPressed: _isCompleting ? null : _confirmNoSports,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text("I DON'T DO OTHER SPORTS"),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Text(
                        'YOUR ACTIVITIES',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),

                      const Spacer(),

                      Text(
                        '${activities.length} TOTAL',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: ForgeColors.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: ForgeSpacing.md),

                  for (var index = 0; index < activities.length; index++) ...[
                    _SportActivityCard(
                      activity: activities[index],
                      onEdit: _isCompleting
                          ? null
                          : () {
                              _editActivity(activities[index]);
                            },
                      onDelete: _isCompleting
                          ? null
                          : () {
                              _deleteActivity(activities[index]);
                            },
                    ),

                    if (index < activities.length - 1)
                      const SizedBox(height: ForgeSpacing.md),
                  ],

                  const SizedBox(height: ForgeSpacing.xxl),

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
                              widget.settingsMode ? 'SAVE CHANGES' : 'CONTINUE',
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
    return Container(
      padding: const EdgeInsets.all(ForgeSpacing.xl),
      decoration: BoxDecoration(
        color: ForgeColors.surface,
        borderRadius: BorderRadius.circular(ForgeRadius.lg),
        border: Border.all(color: ForgeColors.outline),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ForgeColors.surfaceRaised,
              borderRadius: BorderRadius.circular(ForgeRadius.md),
            ),
            child: const Icon(
              Icons.sports_rounded,
              size: 28,
              color: ForgeColors.textMuted,
            ),
          ),

          const SizedBox(height: ForgeSpacing.lg),

          Text(
            'No sports added yet',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),

          const SizedBox(height: 6),

          Text(
            'Add an activity if you '
            'regularly train another sport '
            'alongside your gym sessions.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: ForgeColors.textSecondary, height: 1.4),
          ),
        ],
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
    return Container(
      padding: const EdgeInsets.all(ForgeSpacing.lg),
      decoration: BoxDecoration(
        color: ForgeColors.surface,
        borderRadius: BorderRadius.circular(ForgeRadius.lg),
        border: Border.all(color: ForgeColors.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ForgeColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(ForgeRadius.md),
            ),
            child: const Icon(
              Icons.sports_mma_rounded,
              color: ForgeColors.primary,
              size: 23,
            ),
          ),

          const SizedBox(width: ForgeSpacing.md),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.displayName,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),

                const SizedBox(height: 4),

                Text(
                  weekdayLabel(activity.dayOfWeek),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: ForgeColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  '${activity.durationMinutes} min'
                  ' \u2022 '
                  '${activity.intensity.label} intensity',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: ForgeColors.textSecondary),
                ),
              ],
            ),
          ),

          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_horiz_rounded,
              color: ForgeColors.textMuted,
            ),
            onSelected: (value) {
              if (value == 'edit') {
                onEdit?.call();
              }

              if (value == 'delete') {
                onDelete?.call();
              }
            },
            itemBuilder: (_) {
              return const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 19),
                      SizedBox(width: 10),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 19),
                      SizedBox(width: 10),
                      Text('Delete'),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
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
      insetPadding: const EdgeInsets.symmetric(
        horizontal: ForgeSpacing.lg,
        vertical: ForgeSpacing.xl,
      ),
      contentPadding: EdgeInsets.zero,
      titlePadding: EdgeInsets.zero,
      actionsPadding: EdgeInsets.zero,
      backgroundColor: ForgeColors.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ForgeRadius.xl),
        side: const BorderSide(color: ForgeColors.outline),
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(ForgeSpacing.xl),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
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
                          Icons.sports_mma_rounded,
                          color: ForgeColors.primary,
                          size: 22,
                        ),
                      ),

                      const SizedBox(width: ForgeSpacing.md),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isEditing ? 'EDIT ACTIVITY' : 'ADD ACTIVITY',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              _isEditing
                                  ? 'Update how this sport affects your training schedule.'
                                  : 'Add an activity that may affect recovery and scheduling.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: ForgeColors.textSecondary,
                                    height: 1.35,
                                  ),
                            ),
                          ],
                        ),
                      ),

                      IconButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.close_rounded),
                        color: ForgeColors.textMuted,
                      ),
                    ],
                  ),

                  const SizedBox(height: ForgeSpacing.xl),

                  Text(
                    'ACTIVITY',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: ForgeColors.textSecondary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),

                  const SizedBox(height: ForgeSpacing.sm),

                  TextFormField(
                    controller: _sportController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Sport',
                      hintText: 'e.g. Boxing',
                      prefixIcon: Icon(Icons.sports_rounded),
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

                  const SizedBox(height: ForgeSpacing.lg),

                  DropdownButtonFormField<int>(
                    initialValue: _dayOfWeek,
                    decoration: const InputDecoration(
                      labelText: 'Training Day',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
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

                  const SizedBox(height: ForgeSpacing.lg),

                  TextFormField(
                    controller: _durationController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Duration',
                      suffixText: 'min',
                      prefixIcon: Icon(Icons.schedule_rounded),
                    ),
                    validator: (value) {
                      final duration = int.tryParse(value?.trim() ?? '');

                      if (duration == null) {
                        return 'Enter a valid duration.';
                      }

                      if (duration < 10 || duration > 300) {
                        return 'Duration must be 10\u2013300 minutes.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: ForgeSpacing.lg),

                  DropdownButtonFormField<SportIntensity>(
                    initialValue: _intensity,
                    decoration: const InputDecoration(
                      labelText: 'Intensity',
                      prefixIcon: Icon(Icons.speed_rounded),
                    ),
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

                  const SizedBox(height: ForgeSpacing.xl),

                  Container(
                    padding: const EdgeInsets.all(ForgeSpacing.md),
                    decoration: BoxDecoration(
                      color: ForgeColors.surface,
                      borderRadius: BorderRadius.circular(ForgeRadius.md),
                      border: Border.all(color: ForgeColors.outline),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: ForgeColors.textMuted,
                          size: 18,
                        ),

                        const SizedBox(width: ForgeSpacing.sm),

                        Expanded(
                          child: Text(
                            'FORGE uses the day, '
                            'duration and intensity '
                            'to account for additional '
                            'training stress.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: ForgeColors.textSecondary,
                                  height: 1.35,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: ForgeSpacing.xl),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text('CANCEL'),
                        ),
                      ),

                      const SizedBox(width: ForgeSpacing.md),

                      Expanded(
                        child: FilledButton(
                          onPressed: _submit,
                          child: Text(
                            _isEditing ? 'SAVE CHANGES' : 'ADD ACTIVITY',
                          ),
                        ),
                      ),
                    ],
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
