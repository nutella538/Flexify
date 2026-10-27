import 'package:flexify/sets/history_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_tab_controller.dart';
import 'support/fixtures.dart';
import 'support/test_app.dart';
import 'package:drift/drift.dart';

Future<void> pumpHistoryPage(
  WidgetTester tester,
  FlexifyTestHarness harness, {
  Size? surfaceSize,
}) async {
  await harness.pump(
    tester,
    HistoryPage(tabController: MockTabController()),
    surfaceSize: surfaceSize,
  );
  await tester.pumpAndSettle();
}

Future<int> insertCompletedWorkout(
  FlexifyTestHarness harness, {
  DateTime? startedAt,
  Duration duration = const Duration(minutes: 42),
}) async {
  final start = startedAt ?? testNow;
  return harness.database.workouts.insertOne(
    WorkoutsCompanion.insert(
      startedAt: start,
      endedAt: Value(start.add(duration)),
    ),
  );
}

void main() {
  testWidgets('HistoryPage shows an empty state when there are no completed workouts', (tester) async {
    final harness = await FlexifyTestHarness.create();
    await pumpHistoryPage(tester, harness);

    expect(find.text('No entries yet'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('completed workout expands to show exercises, sets, weights and estimated 10RM', (tester) async {
    final harness = await FlexifyTestHarness.create();
    final workoutId = await insertCompletedWorkout(harness);
    await insertExerciseSetFixture(
      harness.database,
      'Bench press',
      reps: 15,
      weight: 40,
      workoutId: workoutId,
      created: testNow,
    );
    await insertExerciseSetFixture(
      harness.database,
      'Bench press',
      reps: 12,
      weight: 45,
      workoutId: workoutId,
      created: testNow.add(const Duration(minutes: 5)),
    );

    await pumpHistoryPage(tester, harness);

    expect(find.byType(Card), findsOneWidget);
    expect(find.textContaining('42m'), findsOneWidget);
    expect(find.text('Bench press'), findsOneWidget);
    expect(find.text('15 Wdh. · 40 kg · 10RM ~ 30.8 kg'), findsNothing);

    await tester.tap(find.text('Bench press'));
    await tester.pumpAndSettle();

    expect(find.text('Set 1'), findsOneWidget);
    expect(find.text('Set 2'), findsOneWidget);
    expect(find.textContaining('15 Wdh.'), findsOneWidget);
    expect(find.textContaining('40 kg'), findsOneWidget);
    expect(find.textContaining('10RM ~'), findsNWidgets(2));
    expect(find.textContaining('45 kg'), findsOneWidget);
  });

  testWidgets('workout delete asks for confirmation and removes the workout', (tester) async {
    final harness = await FlexifyTestHarness.create();
    final workoutId = await insertCompletedWorkout(harness);
    await insertExerciseSetFixture(
      harness.database,
      'Bench press',
      reps: 10,
      weight: 50,
      workoutId: workoutId,
    );

    await pumpHistoryPage(tester, harness);
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm Delete'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('No entries yet'), findsOneWidget);
    expect(
      await (harness.database.workouts.select()..where((w) => w.id.equals(workoutId))).get(),
      isEmpty,
    );
    expect(
      await (harness.database.exerciseSets.select()..where((s) => s.workoutId.equals(workoutId))).get(),
      isEmpty,
    );
  });

  testWidgets('unfinished workout is not shown in history', (tester) async {
    final harness = await FlexifyTestHarness.create();
    final workoutId = await harness.database.workouts.insertOne(
      WorkoutsCompanion.insert(startedAt: testNow),
    );
    await insertExerciseSetFixture(
      harness.database,
      'Squat',
      reps: 8,
      weight: 60,
      workoutId: workoutId,
    );

    await pumpHistoryPage(tester, harness);

    expect(find.text('Squat'), findsNothing);
    expect(find.text('No entries yet'), findsOneWidget);
  });
}
