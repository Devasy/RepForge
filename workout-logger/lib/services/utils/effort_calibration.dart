// Effort Calibration (rolling, from the once-per-workout chip only)
//
// EffortEstimator anchors every estimate at RPE 8. This is the only real
// calibration signal available for that anchor: a post-workout "how did
// that feel" chip (Easy/Solid/Brutal), answered once per session, not once
// per set. An exponential moving average (alpha ~= 1/10) approximates a
// rolling mean over the last ~10 answered sessions without needing to
// persist per-session history — skipping the chip just means the offset
// stays wherever it last was (0.0 if never answered).

import 'effort_estimator.dart';

class EffortCalibration {
  const EffortCalibration();

  static const double _alpha = 0.1;
  static const double maxOffset = 1.0;

  /// Chip value → the RPE it represents. 1 = Easy, 2 = Solid, 3 = Brutal.
  static const Map<int, double> chipRpe = {1: 6.5, 2: 8.0, 3: 9.5};

  /// Folds one session-effort chip answer into [previousOffset], returning
  /// the new rolling offset to apply to [EffortEstimator.anchorRpe].
  double updateOffset(double previousOffset, int chipValue) {
    final target = chipRpe[chipValue] ?? EffortEstimator.anchorRpe;
    final delta = target - EffortEstimator.anchorRpe;
    return (previousOffset * (1 - _alpha) + delta * _alpha)
        .clamp(-maxOffset, maxOffset);
  }
}
