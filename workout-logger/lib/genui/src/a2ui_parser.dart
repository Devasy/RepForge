import 'dart:convert';

import 'a2ui_node.dart';
import 'a2ui_props.dart';
import 'a2ui_registry.dart';

/// Turns model output into an [A2UiNode] tree, or null when the text is prose.
///
/// This is the single gate that decides whether a reply is a UI payload. Once a
/// tree exists, every spec's `parseProps` is guaranteed to succeed, so no
/// component-level validation is needed or wanted.
class A2UiParser {
  const A2UiParser(this.registry);

  final A2UiRegistry registry;

  /// Canonical name used when auto-wrapping a bare list of components.
  static const String _containerName = 'GridContainer';

  /// Keys that may hold an envelope of components at the top level.
  static const List<String> _envelopeKeys = [
    'components',
    'children',
    'ui',
    'elements',
  ];

  A2UiNode? parse(String text) {
    final json = _extractJson(text);
    if (json == null) return null;
    if (json is List) return _wrap(json);
    if (json is Map) return parseJson(A2UiProps.stringKeyed(json));
    return null;
  }

  A2UiNode? parseJson(Map<String, Object?> json) {
    final props = A2UiProps(json);

    final rawName = props.textOrNull('component');
    final spec = rawName == null ? null : registry.specFor(rawName);

    if (spec == null) {
      // No component key — try each envelope shape before giving up.
      for (final key in _envelopeKeys) {
        final candidate = json[key];
        if (candidate is List) {
          final wrapped = _wrap(candidate, columns: props.integer('columns', or: 1));
          if (wrapped != null) return wrapped;
        }
      }
      return null;
    }

    // Accept both `{component, props:{...}}` and the flat `{component, ...}`.
    final rawProps = json['props'];
    final Map<String, Object?> effective;
    if (rawProps is Map) {
      effective = A2UiProps.stringKeyed(rawProps);
    } else {
      effective = Map<String, Object?>.from(json)..remove('component');
    }

    final children = _parseChildren(A2UiProps(effective));

    // A container that lost every child carries no information — treat the
    // whole payload as unusable so the caller falls back to Markdown.
    if (children.isEmpty && _declaresChildren(effective)) return null;

    return A2UiNode(
      name: spec.name,
      props: A2UiProps(effective),
      children: children,
    );
  }

  /// True when the text is on its way to being a JSON payload, so a streaming
  /// UI can show a "building" indicator instead of raw JSON.
  bool looksLikeUi(String partialText) {
    final t = stripFences(partialText).trimLeft();
    if (t.isEmpty) return false;
    return t.startsWith('{') || t.startsWith('[');
  }

  /// Removes a leading ``` fence (with or without a language tag) and a
  /// trailing ``` fence, tolerating an unterminated fence mid-stream.
  static String stripFences(String text) {
    var t = text.trim();
    if (!t.startsWith('```')) return t;
    final firstLineEnd = t.indexOf('\n');
    t = firstLineEnd == -1 ? '' : t.substring(firstLineEnd + 1);
    if (t.endsWith('```')) t = t.substring(0, t.length - 3);
    return t.trim();
  }

  List<A2UiNode> _parseChildren(A2UiProps props) {
    final raw = props.lookup('children');
    if (raw is! List) return const [];
    final out = <A2UiNode>[];
    for (final child in raw) {
      if (child is! Map) continue;
      final node = parseJson(A2UiProps.stringKeyed(child));
      if (node != null) out.add(node);
    }
    return out;
  }

  bool _declaresChildren(Map<String, Object?> props) =>
      A2UiProps(props).lookup('children') is List;

  A2UiNode? _wrap(List<Object?> items, {int columns = 1}) {
    final children = <A2UiNode>[];
    for (final item in items) {
      if (item is! Map) continue;
      final node = parseJson(A2UiProps.stringKeyed(item));
      if (node != null) children.add(node);
    }
    if (children.isEmpty) return null;
    if (children.length == 1) return children.single;
    return A2UiNode(
      name: _containerName,
      props: A2UiProps({'columns': columns}),
      children: children,
    );
  }

  /// Pulls the outermost JSON object or array out of [text], tolerating
  /// fences and surrounding prose. Returns null when nothing decodes.
  static Object? _extractJson(String text) {
    final t = stripFences(text);
    if (t.isEmpty) return null;

    final candidates = <String>[];
    final firstBrace = t.indexOf('{');
    final lastBrace = t.lastIndexOf('}');
    if (firstBrace != -1 && lastBrace > firstBrace) {
      candidates.add(t.substring(firstBrace, lastBrace + 1));
    }
    final firstBracket = t.indexOf('[');
    final lastBracket = t.lastIndexOf(']');
    if (firstBracket != -1 && lastBracket > firstBracket) {
      candidates.add(t.substring(firstBracket, lastBracket + 1));
    }

    for (final candidate in candidates) {
      try {
        return jsonDecode(candidate);
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}
