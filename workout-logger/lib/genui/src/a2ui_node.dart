import 'a2ui_props.dart';

/// A single parsed node in an A2UI tree.
///
/// [name] is always canonical (as produced by `A2UiRegistry.canonicalName`), so
/// downstream code never re-normalizes. [children] is populated by the parser
/// for any node that carried a `children` array, which keeps container-ness out
/// of individual specs.
class A2UiNode {
  const A2UiNode({
    required this.name,
    required this.props,
    this.children = const [],
  });

  final String name;
  final A2UiProps props;
  final List<A2UiNode> children;

  @override
  String toString() => 'A2UiNode($name, ${children.length} children)';
}
