import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/genui/src/a2ui_parser.dart';
import 'package:repforge/genui/src/default_registry.dart';

void main() {
  final parser = A2UiParser(defaultA2UiRegistry);

  group('payload gate', () {
    test('returns null for ordinary prose', () {
      expect(parser.parse('**Nice work.** Keep going.'), isNull);
      expect(parser.parse(''), isNull);
      expect(parser.parse('Your bench went up 5kg { nice }.'), isNull);
    });

    test('returns null for valid JSON with no known component', () {
      expect(parser.parse('{"component":"HeroBanner","props":{}}'), isNull);
      expect(parser.parse('{"foo":1}'), isNull);
    });

    test('returns null rather than throwing on malformed JSON', () {
      expect(parser.parse('{"component":"StatCard", "props":'), isNull);
      expect(parser.parse('{{{{'), isNull);
    });
  });

  group('extraction', () {
    test('parses a bare object', () {
      final node = parser.parse(
        '{"component":"StatCard","props":{"title":"Volume","value":"12k"}}',
      );
      expect(node?.name, 'StatCard');
      expect(node?.props.text('title'), 'Volume');
    });

    test('strips a fenced code block with a language tag', () {
      final node = parser.parse(
        '```json\n{"component":"StatCard","props":{"title":"V","value":"1"}}\n```',
      );
      expect(node?.name, 'StatCard');
    });

    test('strips a fenced code block without a language tag', () {
      final node = parser.parse(
        '```\n{"component":"StatCard","props":{"title":"V","value":"1"}}\n```',
      );
      expect(node?.name, 'StatCard');
    });

    test('extracts the object from surrounding prose', () {
      final node = parser.parse(
        'Here you go:\n{"component":"StatCard","props":{"title":"V","value":"1"}}\nHope that helps!',
      );
      expect(node?.name, 'StatCard');
    });
  });

  group('shape tolerance', () {
    test('accepts the flat form without a props wrapper', () {
      final node = parser.parse(
        '{"component":"StatCard","title":"Volume","value":"12k"}',
      );
      expect(node?.name, 'StatCard');
      expect(node?.props.text('value'), '12k');
    });

    test('canonicalises a misspelled component name', () {
      expect(parser.parse('{"component":"stat_card","title":"V"}')?.name,
          'StatCard');
      expect(parser.parse('{"component":"Stat Card","title":"V"}')?.name,
          'StatCard');
    });

    test('auto-wraps a bare array of components in a GridContainer', () {
      final node = parser.parse(
        '[{"component":"StatCard","title":"A","value":"1"},'
        '{"component":"StatCard","title":"B","value":"2"}]',
      );
      expect(node?.name, 'GridContainer');
      expect(node?.children, hasLength(2));
    });

    test('auto-wraps a {"components":[...]} envelope', () {
      final node = parser.parse(
        '{"components":[{"component":"StatCard","title":"A","value":"1"}]}',
      );
      expect(node?.name, 'GridContainer');
      expect(node?.children, hasLength(1));
    });
  });

  group('recursion', () {
    test('parses nested children', () {
      final node = parser.parse('''
{"component":"GridContainer","props":{"columns":2,"children":[
  {"component":"StatCard","props":{"title":"A","value":"1"}},
  {"component":"DynamicChart","props":{"type":"bar","title":"C",
    "labels":["Mon"],"values":[1]}}
]}}
''');
      expect(node?.name, 'GridContainer');
      expect(node?.children.map((c) => c.name), ['StatCard', 'DynamicChart']);
    });

    test('drops unrecognised children but keeps the rest', () {
      final node = parser.parse('''
{"component":"GridContainer","children":[
  {"component":"StatCard","title":"A","value":"1"},
  {"component":"HeroBanner","title":"nope"},
  "garbage"
]}
''');
      expect(node?.children, hasLength(1));
      expect(node?.children.single.name, 'StatCard');
    });

    test('returns null when a container loses every child', () {
      expect(
        parser.parse('{"component":"GridContainer","children":['
            '{"component":"HeroBanner"}]}'),
        isNull,
      );
    });
  });

  group('looksLikeUi', () {
    test('is true for a partial payload that has started a JSON object', () {
      expect(parser.looksLikeUi('{"component":"Stat'), isTrue);
      expect(parser.looksLikeUi('```json\n{"comp'), isTrue);
      expect(parser.looksLikeUi('  \n{'), isTrue);
    });

    test('is false for prose and for empty text', () {
      expect(parser.looksLikeUi('Your bench is'), isFalse);
      expect(parser.looksLikeUi(''), isFalse);
      expect(parser.looksLikeUi('**Great** work'), isFalse);
    });
  });
}
