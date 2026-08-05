import 'package:flutter/widgets.dart';

import 'a2ui_node.dart';
import 'a2ui_theme.dart';

/// Prompt-facing documentation for a component.
///
/// This is the single source the LLM system prompt is generated from, so a
/// schema change here propagates to the model automatically.
@immutable
class A2UiDoc {
  const A2UiDoc({
    required this.schema,
    required this.purpose,
    required this.example,
  });

  /// One-line prop signature, e.g. `StatCard {title, value, subtitle?, trend?}`.
  final String schema;

  /// When the model should reach for this component, in one sentence.
  final String purpose;

  /// A complete, valid payload used as a few-shot example.
  final Map<String, Object?> example;
}

/// The four-in-one contract for an A2UI component: it names itself, parses its
/// own props into a typed record, builds itself from that record, and documents
/// itself for the prompt.
///
/// Because all four live on one object, the vocabulary advertised to the model,
/// the shapes accepted by the parser and the shapes consumed by the renderer
/// cannot drift apart.
abstract class A2UiSpec<P extends Object> {
  const A2UiSpec();

  /// Canonical component name as it appears in JSON, e.g. `StatCard`.
  String get name;

  /// Additional names accepted for this component. Matching is case- and
  /// separator-insensitive, so only semantically distinct spellings belong here.
  List<String> get aliases => const [];

  A2UiDoc get doc;

  /// Converts a node into a typed props record.
  ///
  /// Implementations MUST NOT throw and MUST NOT return null — degrade to
  /// documented fallbacks instead. Deciding whether a payload is UI at all is
  /// the parser's job, not this method's.
  P parseProps(A2UiNode node);

  Widget buildWidget(BuildContext context, P props, A2UiTheme theme);

  /// Type-erased entry point used by the renderer.
  Widget render(BuildContext context, A2UiNode node, A2UiTheme theme) =>
      buildWidget(context, parseProps(node), theme);
}
