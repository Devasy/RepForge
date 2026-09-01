import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/genui/src/a2ui_props.dart';

void main() {
  group('A2UiProps key resolution', () {
    test('finds a key by exact match', () {
      const p = A2UiProps({'title': 'Volume'});
      expect(p.text('title'), 'Volume');
    });

    test('finds a key ignoring case, underscores, spaces and hyphens', () {
      expect(const A2UiProps({'x_label': 'Sleep'}).text('xLabel'), 'Sleep');
      expect(const A2UiProps({'X Label': 'Sleep'}).text('xLabel'), 'Sleep');
      expect(const A2UiProps({'XLABEL': 'Sleep'}).text('xLabel'), 'Sleep');
      expect(const A2UiProps({'x-label': 'Sleep'}).text('xLabel'), 'Sleep');
    });

    test('finds a key through a semantic alias', () {
      expect(const A2UiProps({'axes': ['A', 'B']}).stringList('labels'),
          ['A', 'B']);
      expect(const A2UiProps({'name': 'Bench'}).text('title'), 'Bench');
      expect(const A2UiProps({'val': 5}).number('value'), 5);
    });

    test('prefers an exact match over an alias', () {
      const p = A2UiProps({'title': 'Real', 'name': 'Alias'});
      expect(p.text('title'), 'Real');
    });
  });

  group('A2UiProps coercion', () {
    test('text() stringifies numbers and returns fallback for null', () {
      expect(const A2UiProps({'value': 12.5}).text('value'), '12.5');
      expect(const A2UiProps({}).text('value', or: '—'), '—');
    });

    test('number() parses numeric strings and returns fallback otherwise', () {
      expect(const A2UiProps({'value': '12.5'}).number('value'), 12.5);
      expect(const A2UiProps({'value': 'n/a'}).number('value', or: -1), -1);
      expect(const A2UiProps({'value': 7}).number('value'), 7);
    });

    test('numberOrNull() distinguishes absent from zero', () {
      expect(const A2UiProps({}).numberOrNull('min'), isNull);
      expect(const A2UiProps({'min': 0}).numberOrNull('min'), 0);
    });

    test('stringList() stringifies mixed element types', () {
      expect(const A2UiProps({'labels': [1, 'B', 2.5]}).stringList('labels'),
          ['1', 'B', '2.5']);
    });

    test('numberList() coerces string elements and drops unparseable ones', () {
      expect(const A2UiProps({'values': ['1', 2, 'x']}).numberList('values'),
          [1.0, 2.0]);
    });

    test('list accessors return empty for a wrong-typed or missing key', () {
      expect(const A2UiProps({'labels': 'not a list'}).stringList('labels'),
          isEmpty);
      expect(const A2UiProps({}).numberList('values'), isEmpty);
      expect(const A2UiProps({'items': 5}).objectList('items'), isEmpty);
    });

    test('objectList() wraps maps and skips non-maps', () {
      final rows = const A2UiProps({
        'items': [
          {'primaryText': 'Bench'},
          'garbage',
          {'primaryText': 'Squat'},
        ],
      }).objectList('items');
      expect(rows, hasLength(2));
      expect(rows[0].text('primaryText'), 'Bench');
      expect(rows[1].text('primaryText'), 'Squat');
    });

    test('integer() truncates and falls back', () {
      expect(const A2UiProps({'columns': 2.9}).integer('columns'), 2);
      expect(const A2UiProps({'columns': '2'}).integer('columns'), 2);
      expect(const A2UiProps({}).integer('columns', or: 1), 1);
    });
  });
}
