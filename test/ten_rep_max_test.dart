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

  group('recommendProgressiveFirstSetWeight', () {
    test('chooses a load that produces a higher 10RM than last session', () {
      final weight = recommendProgressiveFirstSetWeight(
        previousTenRm: 50,
        step: 2.5,
        targetReps: 15,
      );

      expect(weight, 45);
      expect(weight * (30 + 15) / 40, greaterThan(50));
    });

    test('increases when rounding would otherwise keep the same 10RM', () {
      final weight = recommendProgressiveFirstSetWeight(
        previousTenRm: 50,
        step: 2.5,
        targetReps: 10,
      );

      expect(weight, 52.5);
      expect(weight * (30 + 10) / 40, greaterThan(50));
    });
  });

  group('recommendProgressiveNextSetWeight', () {
    test('always increases load and shows a higher 10RM at target reps', () {
      final weight = recommendProgressiveNextSetWeight(
        currentWeight: 50,
        currentReps: 10,
        step: 2.5,
        targetReps: 15,
      );

      expect(weight, greaterThan(50));
      expect(weight * (30 + 15) / 40, greaterThan(50));
    });

    test('does not regress when current reps are below the target', () {
      final weight = recommendProgressiveNextSetWeight(
        currentWeight: 50,
        currentReps: 12,
        step: 2.5,
        targetReps: 15,
      );

      expect(weight, 52.5);
      expect(weight * (30 + 15) / 40, greaterThan(50 * (30 + 12) / 40));
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
