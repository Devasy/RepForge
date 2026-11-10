import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/utils/program_weekday.dart';

void main() {
  test('weekday names reject out-of-range imported values', () {
    expect(programWeekday(1), 'Monday');
    expect(programWeekday(7), 'Sunday');
    expect(programWeekday(null), isNull);
    for (final day in [-1, 0, 8, 999]) {
      expect(programWeekday(day), isNull);
    }
  });
}
