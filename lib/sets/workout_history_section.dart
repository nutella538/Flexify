import 'package:drift/drift.dart' hide Column;
import 'package:flexify/database/database.dart';
import 'package:flexify/l10n/l10n.dart';
import 'package:flexify/main.dart';
import 'package:flutter/material.dart';

/// A single expandable list of completed workouts, exercises, and their sets.
class WorkoutHistorySection extends StatefulWidget {
  const WorkoutHistorySection({super.key});

  @override
  State<WorkoutHistorySection> createState() => _WorkoutHistorySectionState();
}

class _WorkoutHistorySectionState extends State<WorkoutHistorySection> {
  final Set<int> _deletedWorkoutIds = <int>{};

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Workout>>(
      stream: (db.select(db.workouts)
            ..where((workout) => workout.endedAt.isNotNull())
            ..orderBy([
              (workout) => OrderingTerm.desc(workout.startedAt),
            ])
            ..limit(100))
          .watch(),
      builder: (context, snapshot) {
        final workouts = (snapshot.data ?? const <Workout>[])
            .where((workout) => !_deletedWorkoutIds.contains(workout.id))
            .toList();
        if (workouts.isEmpty) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: Text(context.l10n.noEntriesYet)),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final workout in workouts)
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  key: ValueKey('completed-workout-${workout.id}'),
                  leading: const Icon(Icons.fitness_center_rounded),
                  title: Text(
                    MaterialLocalizations.of(context).formatMediumDate(
                      workout.startedAt.toLocal(),
                    ),
                  ),
                  subtitle: Text(
                    '${context.l10n.workoutDuration}: '
                    '${_duration(workout.endedAt!.difference(workout.startedAt))}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: context.l10n.actionDelete,
                        onPressed: () => _deleteWorkout(context, workout),
                        icon: const Icon(Icons.delete_outline),
                      ),
                      const Icon(Icons.expand_more),
                    ],
                  ),
                  children: [
                    StreamBuilder<List<QueryRow>>(
                      stream: db.customSelect(
                        '''
                        SELECT exercises.id AS exercise_id,
                               exercises.name AS exercise_name,
                               COUNT(*) AS set_count
                        FROM exercise_sets
                        INNER JOIN exercises
                          ON exercises.id = exercise_sets.exercise_id
                        WHERE exercise_sets.workout_id = ?
                        GROUP BY exercises.id, exercises.name
                        ORDER BY MIN(exercise_sets.timestamp)
                        ''',
                        variables: [Variable<int>(workout.id)],
                        readsFrom: {db.exerciseSets, db.exercises},
                      ).watch(),
                      builder: (context, exercisesSnapshot) {
                        final rows =
                            exercisesSnapshot.data ?? const <QueryRow>[];
                        if (rows.isEmpty) {
                          return ListTile(
                             title: Text(context.l10n.noExercisesYet),
                          );
                        }
                        return Column(
                          children: [
                            for (final row in rows)
                              _ExerciseHistoryTile(
                                workoutId: workout.id,
                                exerciseId: row.read<int>('exercise_id'),
                                name: row.read<String>('exercise_name'),
                                setCount: row.read<int>('set_count'),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _deleteWorkout(BuildContext context, Workout workout) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.confirmDelete),
        content: Text(
          '${MaterialLocalizations.of(context).formatMediumDate(workout.startedAt.toLocal())} · '
          '${context.l10n.workoutDuration}: '
          '${_duration(workout.endedAt!.difference(workout.startedAt))}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await db.transaction(() async {
      await (db.exerciseSets.delete()
            ..where((set) => set.workoutId.equals(workout.id)))
          .go();
      await (db.workouts.delete()
            ..where((row) => row.id.equals(workout.id)))
          .go();
    });

    if (!mounted) return;
    setState(() => _deletedWorkoutIds.add(workout.id));
  }

  String _duration(Duration duration) {
    final safeSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
    final hours = safeSeconds ~/ 3600;
    final minutes = (safeSeconds % 3600) ~/ 60;
    final seconds = safeSeconds % 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m ${seconds}s';
  }
}

class _ExerciseHistoryTile extends StatelessWidget {
  final int workoutId;
  final int exerciseId;
  final String name;
  final int setCount;

  const _ExerciseHistoryTile({
    required this.workoutId,
    required this.exerciseId,
    required this.name,
    required this.setCount,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      key: ValueKey('exercise-$workoutId-$exerciseId'),
      tilePadding: const EdgeInsets.symmetric(horizontal: 20),
      childrenPadding: const EdgeInsets.only(left: 16, right: 12, bottom: 8),
      title: Text(name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$setCount ×'),
          const SizedBox(width: 8),
          const Icon(Icons.expand_more),
        ],
      ),
      children: [
        StreamBuilder<List<QueryRow>>(
          stream: db.customSelect(
            '''
            SELECT id, reps, load_kg, duration_ms, distance_metres
            FROM exercise_sets
            WHERE workout_id = ? AND exercise_id = ?
            ORDER BY timestamp, id
            ''',
            variables: [
              Variable<int>(workoutId),
              Variable<int>(exerciseId),
            ],
            readsFrom: {db.exerciseSets},
          ).watch(),
          builder: (context, snapshot) {
            final sets = snapshot.data ?? const <QueryRow>[];
            return Column(
              children: [
                for (var i = 0; i < sets.length; i++)
                  _SetHistoryTile(index: i + 1, row: sets[i]),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SetHistoryTile extends StatelessWidget {
  final int index;
  final QueryRow row;

  const _SetHistoryTile({required this.index, required this.row});

  @override
  Widget build(BuildContext context) {
    final reps = row.readNullable<double>('reps');
    final loadKg = row.readNullable<double>('load_kg');
    final durationMs = row.readNullable<int>('duration_ms');
    final distance = row.readNullable<double>('distance_metres');
    final details = <String>[];
    if (reps != null) details.add('${_number(reps)} Wdh.');
    if (loadKg != null) details.add('${_number(loadKg)} kg');
    if (reps != null && loadKg != null && reps > 0 && reps < 37 && loadKg > 0) {
      // Estimate 1RM with the Brzycki equation, then derive the equivalent 10RM.
      // The estimate is intentionally omitted for very high rep counts where
      // this formula becomes unreliable.
      final oneRmFactor = 1.0278 - 0.0278 * reps;
      if (oneRmFactor > 0) {
        final estimatedOneRm = loadKg / oneRmFactor;
        final estimatedTenRm = estimatedOneRm * (1.0278 - 0.0278 * 10);
        details.add('10RM ~ ${_number(estimatedTenRm)} kg');
      }
    }
    if (distance != null) details.add('${_number(distance / 1000)} km');
    if (durationMs != null && durationMs > 0) {
      final seconds = durationMs ~/ 1000;
      details.add('${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')} min');
    }

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 14,
        child: Text('$index', style: const TextStyle(fontSize: 12)),
      ),
      title: Text(context.l10n.setNumber(index)),
      trailing: Text(details.isEmpty ? '—' : details.join(' · ')),
    );
  }

  String _number(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);
}
