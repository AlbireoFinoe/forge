import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/forge_theme.dart';
import '../data/exercise_summary_data.dart';
import 'exercise_detail_provider.dart';
import 'exercise_detail_sheet.dart';
import 'muscle_visual_assets.dart';

const _muscleCategories = <_MuscleCategory>[
  _MuscleCategory(code: 'CHEST', name: 'Chest'),
  _MuscleCategory(code: 'BACK', name: 'Back'),
  _MuscleCategory(code: 'FRONT_DELTS', name: 'Front Delts'),
  _MuscleCategory(code: 'SIDE_DELTS', name: 'Side Delts'),
  _MuscleCategory(code: 'REAR_DELTS', name: 'Rear Delts'),
  _MuscleCategory(code: 'BICEPS', name: 'Biceps'),
  _MuscleCategory(code: 'TRICEPS', name: 'Triceps'),
  _MuscleCategory(code: 'FOREARMS', name: 'Forearms'),
  _MuscleCategory(code: 'TRAPS', name: 'Traps'),
  _MuscleCategory(code: 'ABS', name: 'Abs'),
  _MuscleCategory(code: 'QUADS', name: 'Quads'),
  _MuscleCategory(code: 'HAMSTRINGS', name: 'Hamstrings'),
  _MuscleCategory(code: 'GLUTES', name: 'Glutes'),
  _MuscleCategory(code: 'CALVES', name: 'Calves'),
];

class ExerciseLibraryScreen extends ConsumerWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercisesAsync = ref.watch(exerciseLibraryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('EXERCISE LIBRARY')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(exerciseLibraryProvider);

          await ref.read(exerciseLibraryProvider.future);
        },
        child: exercisesAsync.when(
          loading: () {
            return const _LibraryLoadingState();
          },
          error: (error, stackTrace) {
            return _LibraryErrorState(
              message: error.toString(),
              onRetry: () {
                ref.invalidate(exerciseLibraryProvider);
              },
            );
          },
          data: (exercises) {
            final counts = <String, int>{};

            for (final exercise in exercises) {
              final code = exercise.primaryMuscleCode.toUpperCase();

              counts[code] = (counts[code] ?? 0) + 1;
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                ForgeSpacing.xl,
                ForgeSpacing.lg,
                ForgeSpacing.xl,
                ForgeSpacing.xxl + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                Text(
                  'Browse every FORGE exercise '
                  'by its primary muscle group.',
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: ForgeColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: ForgeSpacing.xl),
                Row(
                  children: [
                    Text(
                      'MUSCLE GROUPS',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: ForgeColors.textSecondary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${exercises.length} EXERCISES',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: ForgeColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ForgeSpacing.md),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _muscleCategories.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: ForgeSpacing.md,
                    mainAxisSpacing: ForgeSpacing.md,
                    childAspectRatio: 0.78,
                  ),
                  itemBuilder: (context, index) {
                    final muscle = _muscleCategories[index];

                    return _MuscleCard(
                      muscle: muscle,
                      exerciseCount: counts[muscle.code] ?? 0,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) {
                              return MuscleExerciseListScreen(
                                muscleCode: muscle.code,
                                muscleName: muscle.name,
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: ForgeSpacing.xl),
                Text(
                  'Exercise categories use '
                  'FORGE primary muscle groups.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: ForgeColors.textMuted),
                ),
                const SizedBox(height: ForgeSpacing.sm),
                Text(
                  'Exercise data by RepDB (repdb.co)',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: ForgeColors.textMuted),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class MuscleExerciseListScreen extends ConsumerStatefulWidget {
  const MuscleExerciseListScreen({
    required this.muscleCode,
    required this.muscleName,
    super.key,
  });

  final String muscleCode;
  final String muscleName;

  @override
  ConsumerState<MuscleExerciseListScreen> createState() =>
      _MuscleExerciseListScreenState();
}

class _MuscleExerciseListScreenState
    extends ConsumerState<MuscleExerciseListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(
      exercisesByMuscleProvider(widget.muscleCode),
    );

    return Scaffold(
      appBar: AppBar(title: Text(widget.muscleName.toUpperCase())),
      body: exercisesAsync.when(
        loading: () {
          return const Center(child: CircularProgressIndicator());
        },
        error: (error, stackTrace) {
          return _ExerciseListErrorState(
            message: error.toString(),
            onRetry: () {
              ref.invalidate(exercisesByMuscleProvider(widget.muscleCode));
            },
          );
        },
        data: (exercises) {
          final query = _searchQuery.trim().toLowerCase();

          final filtered = query.isEmpty
              ? exercises
              : exercises
                    .where(
                      (exercise) => exercise.name.toLowerCase().contains(query),
                    )
                    .toList(growable: false);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  ForgeSpacing.xl,
                  ForgeSpacing.lg,
                  ForgeSpacing.xl,
                  ForgeSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Exercises where '
                      '${widget.muscleName.toLowerCase()} '
                      'is the primary target.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: ForgeColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: ForgeSpacing.lg),
                    TextField(
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        hintText: 'Search exercises',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: ForgeSpacing.md),
                    Text(
                      '${filtered.length} '
                      '${filtered.length == 1 ? 'EXERCISE' : 'EXERCISES'}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: ForgeColors.textMuted,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const _NoExerciseResults()
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          ForgeSpacing.xl,
                          0,
                          ForgeSpacing.xl,
                          ForgeSpacing.xxl +
                              MediaQuery.paddingOf(context).bottom,
                        ),
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) {
                          return const SizedBox(height: ForgeSpacing.md);
                        },
                        itemBuilder: (context, index) {
                          final exercise = filtered[index];

                          return _ExerciseCard(
                            exercise: exercise,
                            onTap: () {
                              showExerciseDetailSheet(
                                context,
                                exerciseId: exercise.id,
                                exerciseName: exercise.name,
                                showSecondaryMuscles: false,
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MuscleCard extends StatelessWidget {
  const _MuscleCard({
    required this.muscle,
    required this.exerciseCount,
    required this.onTap,
  });

  final _MuscleCategory muscle;
  final int exerciseCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final asset = muscleVisualAssetFor(muscle.code);

    return Material(
      color: ForgeColors.surfaceRaised,
      borderRadius: BorderRadius.circular(ForgeRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ForgeRadius.lg),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ForgeRadius.lg),
            border: Border.all(color: ForgeColors.outline),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(ForgeRadius.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    color: ForgeColors.surfaceSoft,
                    padding: const EdgeInsets.all(ForgeSpacing.sm),
                    child: asset == null
                        ? const Icon(
                            Icons.fitness_center_rounded,
                            size: 48,
                            color: ForgeColors.textMuted,
                          )
                        : Image.asset(
                            asset,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.fitness_center_rounded,
                                size: 48,
                                color: ForgeColors.textMuted,
                              );
                            },
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(ForgeSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              muscle.name.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$exerciseCount '
                              '${exerciseCount == 1 ? 'exercise' : 'exercises'}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: ForgeColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: ForgeColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.exercise, required this.onTap});

  final ExerciseSummaryData exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reps = exercise.minReps == exercise.maxReps
        ? '${exercise.minReps}'
        : '${exercise.minReps}'
              '\u2013'
              '${exercise.maxReps}';

    return Material(
      color: ForgeColors.surfaceRaised,
      borderRadius: BorderRadius.circular(ForgeRadius.lg),
      child: InkWell(
        onTap: onTap,
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ForgeColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(ForgeRadius.md),
                ),
                child: const Icon(
                  Icons.fitness_center_rounded,
                  size: 21,
                  color: ForgeColors.textSecondary,
                ),
              ),

              const SizedBox(width: ForgeSpacing.md),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      '${_titleCase(exercise.difficulty)}'
                      ' \u2022 '
                      '${exercise.isCompound ? 'Compound' : 'Isolation'}',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: ForgeColors.textSecondary),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      '$reps reps'
                      ' \u2022 '
                      '${exercise.restSeconds}s rest',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: ForgeColors.textMuted),
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
    );
  }
}

class _LibraryLoadingState extends StatelessWidget {
  const _LibraryLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 220),
        Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

class _LibraryErrorState extends StatelessWidget {
  const _LibraryErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(ForgeSpacing.xl),
      children: [
        const SizedBox(height: 120),
        const Icon(
          Icons.cloud_off_rounded,
          size: 42,
          color: ForgeColors.textMuted,
        ),
        const SizedBox(height: ForgeSpacing.lg),
        Text(
          'Could not load the exercise library.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: ForgeSpacing.sm),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: ForgeColors.textSecondary),
        ),
        const SizedBox(height: ForgeSpacing.xl),
        FilledButton(onPressed: onRetry, child: const Text('RETRY')),
      ],
    );
  }
}

class _ExerciseListErrorState extends StatelessWidget {
  const _ExerciseListErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ForgeSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 42,
              color: ForgeColors.textMuted,
            ),
            const SizedBox(height: ForgeSpacing.lg),
            Text(
              'Could not load exercises.',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: ForgeSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: ForgeColors.textSecondary),
            ),
            const SizedBox(height: ForgeSpacing.xl),
            FilledButton(onPressed: onRetry, child: const Text('RETRY')),
          ],
        ),
      ),
    );
  }
}

class _NoExerciseResults extends StatelessWidget {
  const _NoExerciseResults();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ForgeSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 42,
              color: ForgeColors.textMuted,
            ),
            const SizedBox(height: ForgeSpacing.md),
            Text(
              'No exercises found',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Try another exercise name.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: ForgeColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _MuscleCategory {
  const _MuscleCategory({required this.code, required this.name});

  final String code;
  final String name;
}

String _titleCase(String value) {
  if (value.isEmpty) {
    return value;
  }

  final normalized = value.replaceAll('_', ' ').toLowerCase();

  return normalized
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map(
        (part) =>
            '${part[0].toUpperCase()}'
            '${part.substring(1)}',
      )
      .join(' ');
}
