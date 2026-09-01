import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/genui/src/a2ui_props.dart';
import 'package:repforge/genui/src/a2ui_series.dart';

void main() {
  group('A2UiSeries.extract', () {
    test('reads an explicit series array', () {
      final series = A2UiSeries.extract(const A2UiProps({
        'series': [
          {'name': 'Biceps', 'values': [1, 2, 3]},
          {'name': 'Triceps', 'values': [4, 5, 6]},
        ],
      }));
      expect(series.map((s) => s.name), ['Biceps', 'Triceps']);
      expect(series[1].values, [4.0, 5.0, 6.0]);
    });

    test('treats a bare values array as one unnamed series', () {
      final series = A2UiSeries.extract(
        const A2UiProps({'title': 'Weekly Sets', 'values': [10, 12]}),
        fallbackName: 'Weekly Sets',
      );
      expect(series, hasLength(1));
      expect(series.single.name, 'Weekly Sets');
      expect(series.single.values, [10.0, 12.0]);
    });

    test('prefers series over values when both are present', () {
      final series = A2UiSeries.extract(const A2UiProps({
        'values': [1],
        'series': [
          {'name': 'A', 'values': [7, 8]}
        ],
      }));
      expect(series, hasLength(1));
      expect(series.single.name, 'A');
      expect(series.single.values, [7.0, 8.0]);
    });

    test("coerces a stringified number inside a series entry's values", () {
      final series = A2UiSeries.extract(const A2UiProps({
        'series': [
          {'name': 'Current', 'values': ['85', 90]}
        ],
      }));
      expect(series.single.values, [85.0, 90.0]);
    });

    test('names an unnamed series entry positionally', () {
      final series = A2UiSeries.extract(const A2UiProps({
        'series': [
          {'values': [1, 2]},
          {'values': [3, 4]},
        ],
      }));
      expect(series.map((s) => s.name), ['Series 1', 'Series 2']);
    });

    test('drops series entries that carry no numeric values', () {
      final series = A2UiSeries.extract(const A2UiProps({
        'series': [
          {'name': 'Good', 'values': [1]},
          {'name': 'Empty', 'values': []},
          {'name': 'Junk', 'values': ['x', 'y']},
        ],
      }));
      expect(series.map((s) => s.name), ['Good']);
    });

    test('returns empty when there is no usable data', () {
      expect(A2UiSeries.extract(const A2UiProps({})), isEmpty);
      expect(A2UiSeries.extract(const A2UiProps({'values': 'nope'})), isEmpty);
    });

    test('falls back to values: when every series entry drops to empty values', () {
      final series = A2UiSeries.extract(
        const A2UiProps({
          'series': [
            {'name': 'A', 'values': []},
            {'name': 'B', 'values': ['x', 'y']}, // unparseable, also drops
          ],
          'values': [10, 20],
        }),
        fallbackName: 'Fallback',
      );
      expect(series, hasLength(1));
      expect(series.single.name, 'Fallback');
      expect(series.single.values, [10.0, 20.0]);
    });

    test('falls back to values: when series is an empty list', () {
      final series = A2UiSeries.extract(
        const A2UiProps({'series': [], 'values': [5, 6]}),
        fallbackName: 'Fallback',
      );
      expect(series, hasLength(1));
      expect(series.single.values, [5.0, 6.0]);
    });
  });

  group('A2UiSeries.maxValue', () {
    test('returns the largest value across all series', () {
      expect(
        A2UiSeries.maxValue(const [
          A2UiSeries(name: 'a', values: [1, 9]),
          A2UiSeries(name: 'b', values: [4, 2]),
        ]),
        9,
      );
    });

    test('returns 0 for empty input', () {
      expect(A2UiSeries.maxValue(const []), 0);
    });

    test('returns the true max when all values are negative', () {
      expect(
        A2UiSeries.maxValue(const [
          A2UiSeries(name: 'a', values: [-5, -2]),
        ]),
        -2.0,
      );
    });
  });

  group('A2UiSeries.minValue', () {
    test('returns the smallest value across all series', () {
      expect(
        A2UiSeries.minValue(const [
          A2UiSeries(name: 'a', values: [1, 9]),
          A2UiSeries(name: 'b', values: [4, 2]),
        ]),
        1,
      );
    });

    test('returns 0 for empty input', () {
      expect(A2UiSeries.minValue(const []), 0);
    });

    test('returns the true min when all values are negative', () {
      expect(
        A2UiSeries.minValue(const [
          A2UiSeries(name: 'a', values: [-5, -2]),
        ]),
        -5.0,
      );
    });
  });
}
