import 'package:drift/drift.dart' hide Column;
import 'package:flexify/database/database.dart';
import 'package:flexify/l10n/l10n.dart';
import 'package:flexify/main.dart';
import 'package:flutter/material.dart';

/// Completed sessions are separate from the legacy exercise-by-exercise history.
class WorkoutHistorySection extends StatefulWidget {
  const WorkoutHistorySection({super.key});

  @override
  State<WorkoutHistorySection> createState() => _WorkoutHistorySectionState();
}

class _WorkoutHistorySectionState extends State<WorkoutHistorySection> {
  // Hide deleted rows immediately as a UI safeguard while Drift's stream refreshes.
  final Set<int> _deletedWorkoutIds = <int>{};

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Workout>>(
      stream: (db.select(db.workouts)
            ..where((workout) => workout.endedAt.isNotNull())
            ..orderBy([
              (workout) => OrderingTerm.desc(workout.startedAt),
            ])
            ..limit(30))
          .watch(),
      builder: (context, snapshot) {
        final workouts = (snapshot.data ?? const <Workout>[])
            .where((workout) => !_deletedWorkoutIds.contains(workout.id))
            .toList();
        if (workouts.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final workout in workouts)
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ExpansionTile(
                  key: ValueKey('completed-workout-${workout.id}'),
                  leading: const Icon(Icons.fitness_center_rounded),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          MaterialLocalizations.of(context).formatMediumDate(
                            workout.startedAt.toLocal(),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: context.l10n.actionDelete,
                        onPressed: () => _deleteWorkout(context, workout),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    '${context.l10n.workoutDuration}: '
                    '${_duration(workout.endedAt!.difference(workout.startedAt))}',
                  ),
                  children: [
                    StreamBuilder<List<QueryRow>>(
                      stream: db.customSelect(
                        '''
                        SELECT exercises.name AS exercise_name,
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
                      builder: (context, setsSnapshot) {
                        final rows = setsSnapshot.data ?? const <QueryRow>[];
                        return Column(
                          children: [
                            for (final row in rows)
                              ListTile(
                                dense: true,
                                title: Text(row.read<String>('exercise_name')),
                                trailing: Text(
                                  '${row.read<int>('set_count')} ×',
                                ),
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
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m ${seconds}s';
  }
}
