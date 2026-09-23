import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/weekdays.dart';
import '../../../core/theme/forge_theme.dart';
import '../../auth/data/auth_user.dart';
import '../../program/data/program_models.dart';
import '../../program/data/program_repository.dart';
import '../../program/presentation/program_controller.dart';
import '../../program/presentation/program_detail_screen.dart';
import '../../workout/data/workout_models.dart';
import '../../workout/data/workout_repository.dart';
import '../../workout/presentation/workout_controller.dart';
import '../../workout/presentation/workout_session_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({required this.user, super.key});

  final AuthUser user;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isGenerating = false;
  bool _isStartingWorkout = false;

  Future<void> _generateProgram({required bool replacingExisting}) async {
    if (_isGenerating) {
      return;
    }

    if (replacingExisting) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Generate a new program?'),
            content: const Text(
              'Your current program will be archived and FORGE will create a new version using your latest training setup.',
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
                child: const Text('Generate'),
              ),
            ],
          );
        },
      );

      if (confirmed != true || !mounted) {
        return;
      }
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      final result = await ref
          .read(programControllerProvider.notifier)
          .generateProgram();

      if (!mounted) {
        return;
      }

      final warningText = result.warnings.isEmpty
          ? ''
          : ' ${result.warnings.length} warning(s) were reported.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Program v${result.versionNumber} generated successfully.$warningText',
          ),
        ),
      );
    } on ProgramException catch (error) {
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
          content: Text('Could not generate your training program.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _openWorkout() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return const WorkoutSessionScreen();
        },
      ),
    );
  }

  Future<void> _startWorkout(ProgramDayData day) async {
    if (_isStartingWorkout) {
      return;
    }

    setState(() {
      _isStartingWorkout = true;
    });

    try {
      await ref.read(workoutControllerProvider.notifier).startWorkout(day.id);

      if (!mounted) {
        return;
      }

      await _openWorkout();
    } on WorkoutException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() {
          _isStartingWorkout = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final program = ref.watch(programControllerProvider);

    final workout = ref.watch(workoutControllerProvider);

    return Scaffold(
      body: program.when(
        loading: () {
          return const Center(child: CircularProgressIndicator());
        },
        error: (error, stackTrace) {
          return _ProgramLoadError(
            error: error,
            onRetry: () {
              ref.read(programControllerProvider.notifier).refresh();
            },
          );
        },
        data: (data) {
          return workout.when(
            loading: () {
              return const Center(child: CircularProgressIndicator());
            },
            error: (error, stackTrace) {
              return _ProgramLoadError(
                error: error,
                onRetry: () {
                  ref.read(workoutControllerProvider.notifier).refresh();
                },
              );
            },
            data: (workoutState) {
              return _HomeContent(
                user: widget.user,
                state: data,
                workoutState: workoutState,
                isGenerating: _isGenerating,
                isStartingWorkout: _isStartingWorkout,
                onRefresh: () async {
                  await Future.wait([
                    ref.read(programControllerProvider.notifier).refresh(),
                    ref.read(workoutControllerProvider.notifier).refresh(),
                  ]);
                },
                onGenerate: () {
                  _generateProgram(replacingExisting: false);
                },
                onRegenerate: () {
                  _generateProgram(replacingExisting: true);
                },
                onStartWorkout: _startWorkout,
                onResumeWorkout: _openWorkout,
              );
            },
          );
        },
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.user,
    required this.state,
    required this.workoutState,
    required this.isGenerating,
    required this.onGenerate,
    required this.onRegenerate,
    required this.isStartingWorkout,
    required this.onStartWorkout,
    required this.onResumeWorkout,
    required this.onRefresh,
  });

  final AuthUser user;
  final ProgramState state;
  final WorkoutState workoutState;

  final bool isGenerating;
  final bool isStartingWorkout;

  final VoidCallback onGenerate;
  final VoidCallback onRegenerate;

  final ValueChanged<ProgramDayData> onStartWorkout;

  final VoidCallback onResumeWorkout;

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final program = state.currentProgram;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            ForgeSpacing.lg,
            ForgeSpacing.lg,
            ForgeSpacing.lg,
            ForgeSpacing.xxl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HomeHeader(fullName: user.fullName),

                  const SizedBox(height: ForgeSpacing.xxl),

                  if (program == null)
                    _NoProgramPanel(
                      isGenerating: isGenerating,
                      onGenerate: onGenerate,
                    )
                  else ...[
                    if (program.isOutdated) ...[
                      _ProgramOutdatedBanner(
                        isGenerating: isGenerating,
                        onRegenerate: onRegenerate,
                      ),
                      const SizedBox(height: ForgeSpacing.lg),
                    ],

                    _TodayTrainingPanel(
                      program: program,
                      currentWorkout: workoutState.currentWorkout,
                      completedToday: workoutState.completedToday,
                      isStartingWorkout: isStartingWorkout,
                      onStartWorkout: onStartWorkout,
                      onResumeWorkout: onResumeWorkout,
                    ),

                    const SizedBox(height: ForgeSpacing.xxl),

                    _AtAGlanceSection(
                      program: program,
                      workoutState: workoutState,
                    ),

                    const SizedBox(height: ForgeSpacing.xxl),

                    _UpNextSection(
                      program: program,
                      onOpenProgram: (day) {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) {
                              return ProgramDetailScreen(
                                program: program,
                                initialDayId: day.id,
                              );
                            },
                          ),
                        );
                      },
                    ),

                    if (state.lastGeneration?.warnings.isNotEmpty ?? false) ...[
                      const SizedBox(height: ForgeSpacing.lg),
                      _GenerationWarningBanner(
                        generation: state.lastGeneration!,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.fullName});

  final String? fullName;

  String? get _firstName {
    final value = fullName?.trim();

    if (value == null || value.isEmpty) {
      return null;
    }

    final parts = value
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return null;
    }

    return parts.first;
  }

  @override
  Widget build(BuildContext context) {
    final firstName = _firstName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FORGE',
          style: Theme.of(context).textTheme.headlineLarge
              ?.copyWith(color: ForgeColors.primary, letterSpacing: -1.3),
        ),
        const SizedBox(height: 6),
        Text(
          firstName == null ? 'Ready to train?' : 'Ready to train, $firstName?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}

class _ProgramOutdatedBanner extends StatelessWidget {
  const _ProgramOutdatedBanner({
    required this.isGenerating,
    required this.onRegenerate,
  });

  final bool isGenerating;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ForgeSpacing.lg),
      decoration: BoxDecoration(
        color: ForgeColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(ForgeRadius.md),
        border: Border.all(color: ForgeColors.warning.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.update_rounded, color: ForgeColors.warning),
          const SizedBox(width: ForgeSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Training setup changed',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Your active program uses an '
                  'older training setup.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: ForgeSpacing.md),
                TextButton(
                  onPressed: isGenerating ? null : onRegenerate,
                  style: TextButton.styleFrom(
                    foregroundColor: ForgeColors.warning,
                    padding: EdgeInsets.zero,
                  ),
                  child: isGenerating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Regenerate program'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoProgramPanel extends StatelessWidget {
  const _NoProgramPanel({required this.isGenerating, required this.onGenerate});

  final bool isGenerating;
  final VoidCallback onGenerate;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: ForgeColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(ForgeRadius.md),
            ),
            child: const Icon(Icons.fitness_center, color: ForgeColors.primary),
          ),
          const SizedBox(height: ForgeSpacing.lg),
          Text(
            'Your setup is ready',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'FORGE can build your first '
            'training program from your '
            'goals, schedule, priorities, '
            'equipment, and sports.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: ForgeSpacing.xl),
          FilledButton(
            onPressed: isGenerating ? null : onGenerate,
            child: isGenerating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Text('Generate My Program'),
          ),
        ],
      ),
    );
  }
}

class _TodayTrainingPanel extends StatelessWidget {
  const _TodayTrainingPanel({
    required this.program,
    required this.currentWorkout,
    required this.completedToday,
    required this.isStartingWorkout,
    required this.onStartWorkout,
    required this.onResumeWorkout,
  });

  final ProgramDetailData program;

  final WorkoutSessionData? currentWorkout;

  final WorkoutSummaryData? completedToday;

  final bool isStartingWorkout;

  final ValueChanged<ProgramDayData> onStartWorkout;

  final VoidCallback onResumeWorkout;

  ProgramDayData? _todaySession() {
    final today = DateTime.now().weekday;

    for (final day in program.days) {
      if (day.dayOfWeek == today) {
        return day;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final session = _todaySession();
    final inProgress = currentWorkout;
    final completed = completedToday;

    final completedScheduledSession =
        session != null &&
        completed != null &&
        completed.programVersionNumber == program.versionNumber &&
        completed.dayOfWeek == session.dayOfWeek;

    final primarySessionName =
        inProgress?.dayName ?? session?.name ?? 'Recovery Day';

    return Container(
      padding: const EdgeInsets.all(ForgeSpacing.xl),
      decoration: BoxDecoration(
        color: ForgeColors.surfaceRaised,
        borderRadius: BorderRadius.circular(ForgeRadius.lg),
        border: Border.all(color: ForgeColors.outlineStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                inProgress != null ? 'IN PROGRESS' : 'TODAY',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: ForgeColors.primary,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (completedScheduledSession)
                const _StatusPill(
                  icon: Icons.check_rounded,
                  label: 'DONE',
                  color: ForgeColors.success,
                ),
            ],
          ),

          const SizedBox(height: ForgeSpacing.lg),

          Text(
            primarySessionName,
            style: Theme.of(context).textTheme.headlineLarge,
          ),

          const SizedBox(height: 8),

          if (inProgress != null)
            Text(
              'Workout session in progress',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else if (session == null)
            Text(
              'No programmed gym session '
              'today. Recover and come back '
              'strong.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _MetaItem(
                  icon: Icons.calendar_today_outlined,
                  label: weekdayLabel(session.dayOfWeek),
                ),
                _MetaItem(
                  icon: Icons.schedule_outlined,
                  label: '${session.estimatedDurationMinutes} min',
                ),
                _MetaItem(
                  icon: Icons.fitness_center,
                  label: '${session.exercises.length} exercises',
                ),
              ],
            ),

          if (inProgress != null) ...[
            const SizedBox(height: ForgeSpacing.xl),
            FilledButton.icon(
              onPressed: onResumeWorkout,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('RESUME WORKOUT'),
            ),
          ] else if (session != null && !completedScheduledSession) ...[
            const SizedBox(height: ForgeSpacing.xl),
            FilledButton.icon(
              onPressed: isStartingWorkout
                  ? null
                  : () {
                      onStartWorkout(session);
                    },
              icon: const Icon(Icons.play_arrow_rounded),
              label: isStartingWorkout
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text('START WORKOUT'),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: ForgeColors.textSecondary),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _UpNextSection extends StatelessWidget {
  const _UpNextSection({required this.program, required this.onOpenProgram});

  final ProgramDetailData program;
  final ValueChanged<ProgramDayData> onOpenProgram;

  ProgramDayData? _nextSession() {
    if (program.days.isEmpty) {
      return null;
    }

    final today = DateTime.now().weekday;

    ProgramDayData? result;
    var smallestOffset = 8;

    for (final day in program.days) {
      var offset = (day.dayOfWeek - today + 7) % 7;

      if (offset == 0) {
        offset = 7;
      }

      if (offset < smallestOffset) {
        smallestOffset = offset;
        result = day;
      }
    }

    return result;
  }

  int _daysUntil(ProgramDayData day) {
    final today = DateTime.now().weekday;

    var offset = (day.dayOfWeek - today + 7) % 7;

    if (offset == 0) {
      offset = 7;
    }

    return offset;
  }

  String _dayCaption(ProgramDayData day) {
    final offset = _daysUntil(day);

    if (offset == 1) {
      return 'TOMORROW';
    }

    return weekdayLabel(day.dayOfWeek).toUpperCase();
  }

  String _shortDay(ProgramDayData day) {
    final value = weekdayLabel(day.dayOfWeek);

    if (value.length <= 3) {
      return value.toUpperCase();
    }

    return value.substring(0, 3).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final next = _nextSession();

    if (next == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'UP NEXT',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: ForgeColors.textSecondary,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),

        const SizedBox(height: ForgeSpacing.md),

        Material(
          color: ForgeColors.surface,
          borderRadius: BorderRadius.circular(ForgeRadius.lg),
          child: InkWell(
            onTap: () {
              onOpenProgram(next);
            },
            borderRadius: BorderRadius.circular(ForgeRadius.lg),
            child: Container(
              padding: const EdgeInsets.all(ForgeSpacing.lg),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ForgeRadius.lg),
                border: Border.all(color: ForgeColors.outline),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ForgeColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(ForgeRadius.md),
                    ),
                    child: Text(
                      _shortDay(next),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: ForgeColors.primary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  const SizedBox(width: ForgeSpacing.md),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _dayCaption(next),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: ForgeColors.textMuted,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          next.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          '${next.estimatedDurationMinutes} min'
                          ' ? '
                          '${next.exercises.length} exercises',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: ForgeColors.textSecondary),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: ForgeSpacing.sm),

                  const Icon(
                    Icons.chevron_right_rounded,
                    color: ForgeColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AtAGlanceSection extends StatefulWidget {
  const _AtAGlanceSection({required this.program, required this.workoutState});

  final ProgramDetailData program;
  final WorkoutState workoutState;

  @override
  State<_AtAGlanceSection> createState() => _AtAGlanceSectionState();
}

class _AtAGlanceSectionState extends State<_AtAGlanceSection> {
  late final PageController _pageController;

  int _page = 0;

  @override
  void initState() {
    super.initState();

    _pageController = PageController(viewportFraction: 0.9);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AT A GLANCE',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: ForgeColors.textSecondary,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),

        const SizedBox(height: ForgeSpacing.md),

        SizedBox(
          height: 184,
          child: PageView(
            controller: _pageController,
            padEnds: false,
            onPageChanged: (value) {
              setState(() {
                _page = value;
              });
            },
            children: [
              Padding(
                padding: const EdgeInsets.only(right: ForgeSpacing.md),
                child: _WeeklySnapshotCard(
                  program: widget.program,
                  workoutState: widget.workoutState,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: ForgeSpacing.md),
                child: _ProgramSnapshotCard(program: widget.program),
              ),
            ],
          ),
        ),

        const SizedBox(height: ForgeSpacing.md),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var index = 0; index < 2; index++) ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: _page == index ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _page == index
                      ? ForgeColors.primary
                      : ForgeColors.outlineStrong,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              if (index == 0) const SizedBox(width: 6),
            ],
          ],
        ),
      ],
    );
  }
}

class _WeeklySnapshotCard extends StatelessWidget {
  const _WeeklySnapshotCard({
    required this.program,
    required this.workoutState,
  });

  final ProgramDetailData program;
  final WorkoutState workoutState;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final weekStart = today.subtract(Duration(days: now.weekday - 1));

    final weekEnd = weekStart.add(const Duration(days: 7));

    final scheduledDays = program.days.map((day) => day.dayOfWeek).toSet();

    final completedDays = <int>{};

    for (final workout in workoutState.history) {
      final completedAt = workout.completedAt;

      if (workout.status != 'completed' ||
          completedAt == null ||
          workout.programVersionNumber != program.versionNumber) {
        continue;
      }

      final local = completedAt.toLocal();

      if (!local.isBefore(weekStart) &&
          local.isBefore(weekEnd) &&
          scheduledDays.contains(workout.dayOfWeek)) {
        completedDays.add(workout.dayOfWeek);
      }
    }

    final completedCount = completedDays.length;

    final totalDays = scheduledDays.length;

    final progress = totalDays == 0 ? 0.0 : completedCount / totalDays;

    final remaining = totalDays > completedCount
        ? totalDays - completedCount
        : 0;

    return _SnapshotCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WEEKLY PROGRESS',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: ForgeColors.textSecondary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),

          const Spacer(),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$completedCount / $totalDays',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: ForgeColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  'SESSIONS',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: ForgeColors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: ForgeSpacing.md),

          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: ForgeColors.surfaceSoft,
            ),
          ),

          const SizedBox(height: ForgeSpacing.sm),

          Text(
            remaining == 0 && totalDays > 0
                ? 'Weekly training complete.'
                : '$remaining remaining this week',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: ForgeColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ProgramSnapshotCard extends StatelessWidget {
  const _ProgramSnapshotCard({required this.program});

  final ProgramDetailData program;

  @override
  Widget build(BuildContext context) {
    return _SnapshotCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'CURRENT PROGRAM',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: ForgeColors.textSecondary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: ForgeColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  'V${program.versionNumber}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: ForgeColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const Spacer(),

          Text(
            program.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),

          const SizedBox(height: 6),

          Text(
            '${_goalLabel(program.goal)}'
            ' ? '
            '${program.days.length} days/week',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: ForgeColors.textSecondary),
          ),

          const SizedBox(height: 4),

          Text(
            '${program.totalExercises} '
            'exercise assignments',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: ForgeColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _SnapshotCard extends StatelessWidget {
  const _SnapshotCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ForgeSpacing.lg),
      decoration: BoxDecoration(
        color: ForgeColors.surface,
        borderRadius: BorderRadius.circular(ForgeRadius.lg),
        border: Border.all(color: ForgeColors.outline),
      ),
      child: child,
    );
  }
}

class _GenerationWarningBanner extends StatelessWidget {
  const _GenerationWarningBanner({required this.generation});

  final ProgramGenerateData generation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ForgeSpacing.lg),
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
            color: ForgeColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: ForgeSpacing.md),
          Expanded(
            child: Text(
              'Program generated with '
              '${generation.warnings.length} '
              'optimization warning(s). '
              'These are not generation '
              'failures.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgramLoadError extends StatelessWidget {
  const _ProgramLoadError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 16),
            const Text('Could not load your training program.'),
            const SizedBox(height: 8),
            Text(error.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

String _goalLabel(String value) {
  switch (value) {
    case 'muscle_gain':
      return 'Muscle Gain';
    case 'strength':
      return 'Strength';
    case 'fat_loss':
      return 'Fat Loss';
    case 'general_fitness':
      return 'General Fitness';
    case 'hybrid':
      return 'Hybrid';
    default:
      return value;
  }
}
