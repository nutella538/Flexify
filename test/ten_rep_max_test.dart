import 'package:flexify/plan/ten_rep_max.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('estimateTenRm', () {
    test('estimates 10RM from a 10-repetition set', () {
      expect(
        estimateTenRm([const TenRmSet(weight: 50, reps: 10)]),
        50,
      );
    });

    test('estimates 10RM from higher-repetition sets', () {
      expect(
        estimateTenRm([const TenRmSet(weight: 50, reps: 20)]),
        62.5,
      );
    });

    test('uses the median to reduce the effect of an outlier', () {
      expect(
        estimateTenRm([
          const TenRmSet(weight: 50, reps: 10),
          const TenRmSet(weight: 100, reps: 10),
          const TenRmSet(weight: 52, reps: 10),
        ]),
        52,
      );
    });

    test('ignores invalid loads and sets above 25 reps', () {
      expect(
        estimateTenRm([
          const TenRmSet(weight: 0, reps: 10),
          const TenRmSet(weight: 50, reps: 30),
          const TenRmSet(weight: 40, reps: 10),
        ]),
        40,
      );
      expect(
        estimateTenRm([const TenRmSet(weight: 50, reps: 30)]),
        isNull,
      );
    });
  });

  group('recommendNextSetWeight', () {
    test('reduces the load when fewer than 15 reps are achieved', () {
      expect(
        recommendNextSetWeight(
          tenRm: 60,
          lastWeight: 50,
          lastReps: 14,
          step: 2.5,
        ),
        47.5,
      );
    });

    test('keeps the load up to four reps above target', () {
      expect(
        recommendNextSetWeight(
          tenRm: 60,
          lastWeight: 50,
          lastReps: 19,
          step: 2.5,
        ),
        50,
      );
    });

    test('uses each exercise target when recommending the next load', () {
      expect(
        recommendNextSetWeight(
          tenRm: 60,
          lastWeight: 50,
          lastReps: 9,
          step: 2.5,
          targetReps: 10,
        ),
        47.5,
      );
      expect(
        recommendNextSetWeight(
          tenRm: 60,
          lastWeight: 50,
          lastReps: 20,
          step: 2.5,
          targetReps: 16,
        ),
        50,
      );
      expect(
        recommendNextSetWeight(
          tenRm: 60,
          lastWeight: 50,
          lastReps: 21,
          step: 2.5,
          targetReps: 16,
        ),
        52.5,
      );
      expect(
        recommendNextSetWeight(
          tenRm: 60,
          lastWeight: 50,
          lastReps: 26,
          step: 2.5,
          targetReps: 16,
        ),
        52.5,
      );
    });

    test('increases the load at target plus five reps', () {
      expect(
        recommendNextSetWeight(
          tenRm: 60,
          lastWeight: 50,
          lastReps: 20,
          step: 2.5,
        ),
        52.5,
      );
    });
  });
}
