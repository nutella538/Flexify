/// Estimate a 10-repetition maximum from recent strength-training sets.
///
/// Uses an Epley-derived estimate and the median of recent valid sets to reduce
/// the influence of unusually good or poor individual sets. Estimates from
/// very high-repetition sets are deliberately excluded because they are less
/// reliable.
class TenRmSet {
  const TenRmSet({required this.weight, required this.reps});

  final double weight;
  final double reps;
}

double? estimateTenRm(Iterable<TenRmSet> sets, {int maxSamples = 10}) {
  if (maxSamples <= 0) return null;

  final estimates = <double>[];
  for (final set in sets) {
    if (!set.weight.isFinite ||
        !set.reps.isFinite ||
        set.weight <= 0 ||
        set.reps < 5 ||
        set.reps > 25) {
      continue;
    }

    estimates.add(set.weight * (30 + set.reps) / 40);
    if (estimates.length >= maxSamples) break;
  }

  if (estimates.isEmpty) return null;
  estimates.sort();
  final middle = estimates.length ~/ 2;
  if (estimates.length.isOdd) return estimates[middle];
  return (estimates[middle - 1] + estimates[middle]) / 2;
}

/// Suggests the next load around an exercise-specific target repetition count.
///
/// The 10RM estimate provides a baseline for the requested target. Actual
/// performance in the latest set takes precedence: reduce below target reps,
/// keep the load up to four reps above target, and increase at target + 5.
double recommendNextSetWeight({
  required double tenRm,
  required double lastWeight,
  required double lastReps,
  required double step,
  int targetReps = 15,
}) {
  final safeStep = step > 0 && step.isFinite ? step : 1.0;
  final safeTarget = targetReps.clamp(1, 50);
  final baseline = _roundToStep(tenRm * 40 / (30 + safeTarget), safeStep);

  if (!lastWeight.isFinite || lastWeight <= 0 || !lastReps.isFinite || lastReps <= 0) {
    return baseline;
  }

  if (lastReps < safeTarget) {
    final lower = lastWeight - safeStep;
    return lower > 0 ? _roundToStep(lower, safeStep) : lastWeight;
  }

  if (lastReps >= safeTarget + 5) {
    final increase = _roundToStep(lastWeight + safeStep, safeStep);
    return increase > baseline ? increase : baseline;
  }

  return _roundToStep(lastWeight, safeStep);
}

double _roundToStep(double weight, double step) =>
    (weight / step).round() * step;


/// Recommends the smallest load increment whose estimated 10RM is strictly
/// higher than the previous session's first-set 10RM at the target rep count.
double recommendProgressiveFirstSetWeight({
  required double previousTenRm,
  required double step,
  int targetReps = 15,
}) {
  final safeStep = step > 0 && step.isFinite ? step : 1.0;
  final safeTarget = targetReps.clamp(1, 50);
  if (!previousTenRm.isFinite || previousTenRm <= 0) return 0;

  var candidate = _roundUpToStep(
    previousTenRm * 40 / (30 + safeTarget),
    safeStep,
  );
  // A rounded value can still estimate to the same 10RM. Advance until it is
  // strictly higher, allowing for floating-point rounding noise.
  while (candidate * (30 + safeTarget) / 40 <= previousTenRm + 1e-9) {
    candidate += safeStep;
  }
  return candidate;
}

double _roundUpToStep(double weight, double step) =>
    (weight / step).ceil() * step;
