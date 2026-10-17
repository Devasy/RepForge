import 'package:ai_orchestration/ai_orchestration.dart';
import 'package:test/test.dart';
import 'support.dart';

void main() {
  test('validates nested arguments, enums, required keys and bounds', () {
    final schema = ValueSchema.object(
      properties: {
        'kind': ValueSchema.string(values: ['expense', 'income']),
        'days': ValueSchema.integer(minimum: 1, maximum: 30),
        'items': ValueSchema({
          'type': 'array',
          'minItems': 1,
          'maxItems': 2,
          'items': {'type': 'boolean'},
        }),
      },
      required: ['kind', 'days', 'items'],
    );
    schema.validate({
      'kind': 'expense',
      'days': 7,
      'items': [true],
    });
    for (final invalid in <JsonMap>[
      {
        'kind': 'other',
        'days': 7,
        'items': [true],
      },
      {
        'kind': 'expense',
        'days': 0,
        'items': [true],
      },
      {'kind': 'expense', 'days': 7, 'items': []},
      {
        'kind': 'expense',
        'days': 7,
        'items': ['yes'],
      },
      {'kind': 'expense', 'days': 7},
      {
        'kind': 'expense',
        'days': 7,
        'items': [true],
        'unexpected': 1,
      },
    ]) {
      expect(
        () => schema.validate(invalid),
        throwsA(isA<OrchestrationException>()),
      );
    }
  });
  test(
    'unsupported schema features fail instead of being silently ignored',
    () {
      expect(
        () => ValueSchema({'type': 'string', 'pattern': '.*'}),
        throwsArgumentError,
      );
      expect(() => ValueSchema({'type': 'array'}), throwsArgumentError);
      expect(
        () => ValueSchema.object(required: ['missing']),
        throwsArgumentError,
      );
    },
  );
  test('registry rejects duplicate tool IDs', () {
    final tool = CallbackTool('same', (_) => ToolSuccess({}));
    expect(() => ToolRegistry([tool, tool]), throwsArgumentError);
  });
  test(
    'JSON snapshots reject unsupported data and canonicalize map ordering',
    () {
      expect(() => freezeJson({'bad': double.infinity}), throwsArgumentError);
      expect(() => freezeJson({'bad': DateTime.now()}), throwsArgumentError);
      expect(
        canonicalJson({
          'b': 1,
          'a': [2],
        }),
        canonicalJson({
          'a': [2],
          'b': 1,
        }),
      );
    },
  );
}
