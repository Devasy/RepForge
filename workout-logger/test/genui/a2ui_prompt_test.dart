import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/genui/a2ui.dart';

void main() {
  final section = buildA2UiPromptSection(defaultA2UiRegistry);

  test('names every registered component', () {
    for (final spec in defaultA2UiRegistry.specs) {
      expect(section, contains(spec.name), reason: spec.name);
    }
  });

  test('includes every schema line verbatim', () {
    for (final spec in defaultA2UiRegistry.specs) {
      expect(section, contains(spec.doc.schema), reason: spec.name);
    }
  });

  test('includes every purpose line', () {
    for (final spec in defaultA2UiRegistry.specs) {
      expect(section, contains(spec.doc.purpose), reason: spec.name);
    }
  });

  test('mentions no component the registry does not have', () {
    expect(section, isNot(contains('HeroCard')));
    expect(section, isNot(contains('axes:')));
  });

  test('contains a worked example that the parser accepts', () {
    // The prompt's "Envelope: {...}" description line uses placeholder
    // braces (<Name>, ...) that aren't valid JSON, so the real example must
    // be located after the "WORKED EXAMPLE:" marker rather than by the
    // section's first '{' overall.
    final markerIndex = section.indexOf('WORKED EXAMPLE:');
    expect(markerIndex, greaterThan(-1));
    final start = section.indexOf('{', markerIndex);
    expect(start, greaterThan(-1));
    // Walk forward counting brace depth so the extracted region is exactly
    // the balanced JSON object starting at `start`, regardless of whether
    // prompt content appended after the worked example also contains '}'.
    var depth = 0;
    var end = -1;
    for (var i = start; i < section.length; i++) {
      if (section[i] == '{') depth++;
      if (section[i] == '}') {
        depth--;
        if (depth == 0) {
          end = i;
          break;
        }
      }
    }
    expect(end, greaterThan(-1));
    final example = section.substring(start, end + 1);

    final decoded = jsonDecode(example);
    expect(decoded, isA<Map<String, Object?>>());

    final node = A2UiParser(defaultA2UiRegistry)
        .parseJson(decoded as Map<String, Object?>);
    expect(node, isNotNull);
    expect(node!.name, 'GridContainer');
    expect(node.children, isNotEmpty);
  });

  test('states the tolerance rules so the model is not over-constrained', () {
    expect(section.toLowerCase(), contains('number'));
    expect(section.toLowerCase(), contains('ignored'));
  });

  test('is deterministic across calls so prompt caching can engage', () {
    expect(buildA2UiPromptSection(defaultA2UiRegistry), section);
  });
}
