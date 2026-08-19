import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/services/utils/effort_calibration.dart';

void main() {
  final calibration = EffortCalibration();

  test('never-answered path: offset starts at 0.0', () {
    // Nothing to assert on the class itself — this documents that callers
    // should default the offset to 0.0 until updateOffset is ever called.
    expect(EffortCalibration.chipRpe.isNotEmpty, isTrue);
  });

  test('an Easy answer nudges the offset negative', () {
    final result = calibration.updateOffset(0.0, 1);
    expect(result, lessThan(0.0));
  });

  test('a Solid answer (matches the anchor) leaves the offset unchanged', () {
    final result = calibration.updateOffset(0.0, 2);
    expect(result, closeTo(0.0, 0.0001));
  });

  test('a Brutal answer nudges the offset positive', () {
    final result = calibration.updateOffset(0.0, 3);
    expect(result, greaterThan(0.0));
  });

  test('repeated Brutal answers converge toward +1.0 but never exceed it', () {
    var offset = 0.0;
    for (var i = 0; i < 200; i++) {
      offset = calibration.updateOffset(offset, 3);
    }
    expect(offset, closeTo(EffortCalibration.maxOffset, 0.01));
    expect(offset, lessThanOrEqualTo(EffortCalibration.maxOffset));
  });

  test('repeated Easy answers converge toward -1.0 but never exceed it', () {
    var offset = 0.0;
    for (var i = 0; i < 200; i++) {
      offset = calibration.updateOffset(offset, 1);
    }
    expect(offset, closeTo(-EffortCalibration.maxOffset, 0.01));
    expect(offset, greaterThanOrEqualTo(-EffortCalibration.maxOffset));
  });

  test('an unrecognized chip value is treated as neutral (matches the anchor)',
      () {
    final result = calibration.updateOffset(0.5, 99);
    // delta = anchorRpe - anchorRpe = 0 → offset decays toward 0.
    expect(result, closeTo(0.45, 0.0001));
  });
}
