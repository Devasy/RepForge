import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/genui/src/a2ui_node.dart';
import 'package:repforge/genui/src/a2ui_parser.dart';
import 'package:repforge/genui/src/a2ui_registry.dart';
import 'package:repforge/genui/src/a2ui_spec.dart';
import 'package:repforge/genui/src/a2ui_theme.dart';

class _StubSpec extends A2UiSpec<String> {
  const _StubSpec(this.name);
  @override
  final String name;
  @override
  A2UiDoc get doc =>
      A2UiDoc(schema: '$name {}', purpose: 'stub', example: const {});
  @override
  String parseProps(A2UiNode node) => node.props.text('title');
  @override
  Widget buildWidget(BuildContext context, String props, A2UiTheme theme) =>
      const SizedBox.shrink();
}

void main() {
  final parser = A2UiParser(A2UiRegistry(const [
    _StubSpec('StatCard'),
    _StubSpec('GridContainer'),
  ]));

  test('rejects prose and malformed JSON', () {
    expect(parser.parse('**Nice work.**'), isNull);
    expect(parser.parse('{"component":"StatCard", "props":'), isNull);
  });

  test('parses fenced, prose-wrapped and flat payloads', () {
    expect(parser.parse('```json\n{"component":"StatCard","title":"V"}\n```')?.name,
        'StatCard');
    expect(parser.parse('Sure:\n{"component":"stat_card","title":"V"}\nOk')?.name,
        'StatCard');
  });

  test('auto-wraps arrays and recurses into children', () {
    final wrapped = parser.parse(
      '[{"component":"StatCard","title":"A"},{"component":"StatCard","title":"B"}]',
    );
    expect(wrapped?.name, 'GridContainer');
    expect(wrapped?.children, hasLength(2));

    final nested = parser.parse(
      '{"component":"GridContainer","children":['
      '{"component":"StatCard","title":"A"},{"component":"Nope"}]}',
    );
    expect(nested?.children, hasLength(1));
  });

  test('looksLikeUi discriminates partial JSON from prose', () {
    expect(parser.looksLikeUi('{"comp'), isTrue);
    expect(parser.looksLikeUi('Your bench'), isFalse);
  });

  group('stray braces in surrounding prose', () {
    test('ignores a stray brace before the payload', () {
      final node = parser.parse(
        'Note: use {this} format. {"component":"StatCard","title":"A"}',
      );
      expect(node?.name, 'StatCard');
      expect(node?.props.text('title'), 'A');
    });

    test('ignores a stray brace after the payload', () {
      final node = parser.parse(
        'Here: {"component":"StatCard","title":"A"} Cool, right? {ok}',
      );
      expect(node?.name, 'StatCard');
      expect(node?.props.text('title'), 'A');
    });

    test('still extracts the object from ordinary surrounding prose', () {
      final node = parser.parse(
        'Here you go:\n{"component":"StatCard","title":"V"}\nHope that helps!',
      );
      expect(node?.name, 'StatCard');
    });
  });

  group('singleton collapse behavior', () {
    test('a single-item envelope still wraps in a GridContainer', () {
      final node = parser.parse(
        '{"components":[{"component":"StatCard","title":"A","value":"1"}]}',
      );
      expect(node?.name, 'GridContainer');
      expect(node?.children, hasLength(1));
      expect(node?.children.single.name, 'StatCard');
    });

    test('a single-item bare array collapses to the bare component', () {
      final node = parser.parse(
        '[{"component":"StatCard","title":"A","value":"1"}]',
      );
      expect(node?.name, 'StatCard');
      expect(node?.children, isEmpty);
    });
  });
}
