import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/services/utils/effort_calibration.dart';

void main() {
  const calibration = EffortCalibration();

  test('chipRpe maps every effort chip to an RPE anchor', () {
    // The chip values are what WorkoutSummaryScreen sends to
    // recordSessionEffort; a gap here would make a chip silently inert.
    expect(EffortCalibration.chipRpe.keys, containsAll(<int>[1, 2, 3]));
    for (final entry in EffortCalibration.chipRpe.entries) {
      expect(entry.value, inInclusiveRange(1.0, 10.0), reason: '${entry.key}');
    }
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
