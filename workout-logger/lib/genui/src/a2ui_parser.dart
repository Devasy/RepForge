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

  /// Keys that may hold a node's structural child components.
  ///
  /// This mirrors `_envelopeKeys` minus `ui` (which only makes sense as a
  /// whole-document envelope, not a per-node prop): `components`/`elements`/
  /// `content` are accepted tolerantly alongside the canonical `children`,
  /// but `items` is deliberately excluded — see `_firstChildList` for why.
  static const List<String> _childKeys = [
    'children',
    'components',
    'elements',
    'content',
  ];

  A2UiNode? parse(String text) {
    final json = _extractJson(text);
    if (json == null) return null;
    // A bare top-level array is ambiguous when it holds exactly one item —
    // it may be an intentional list or just a single component that happens
    // to be array-wrapped, so a single item collapses to itself rather than
    // being wrapped in a container.
    if (json is List) return _wrap(json, collapseSingle: true);
    if (json is Map) return parseJson(A2UiProps.stringKeyed(json));
    return null;
  }

  A2UiNode? parseJson(Map<String, Object?> json) {
    final props = A2UiProps(json);

    final rawName = props.textOrNull('component');
    final spec = rawName == null ? null : registry.specFor(rawName);

    if (spec == null) {
      // No component key — try each envelope shape before giving up. An
      // envelope key is an explicit "this is a container of components"
      // signal from the model, so even a single-item envelope still
      // produces a GridContainer rather than collapsing to the bare child.
      for (final key in _envelopeKeys) {
        final candidate = json[key];
        if (candidate is List) {
          final wrapped = _wrap(
            candidate,
            columns: props.integer('columns', or: 1),
            collapseSingle: false,
          );
          if (wrapped != null) return wrapped;
        }
      }
      return null;
    }

    // Accept both `{component, props:{...}}` and the flat `{component, ...}`.
    final rawProps = json['props'];
    final Map<String, Object?> effective;
    if (rawProps is Map) {
      final merged = A2UiProps.stringKeyed(rawProps);
      // A model may write a node's children as a sibling of `props` rather
      // than nested inside it, e.g. `{component, props:{...}, children:[...]}`.
      // Fold any such outer child-key into `effective` when `props` doesn't
      // already define it — `props` always wins on a genuine conflict.
      for (final key in _childKeys) {
        if (!merged.containsKey(key) && json.containsKey(key)) {
          merged[key] = json[key];
        }
      }
      effective = merged;
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
    if (t.isNotEmpty && (t.startsWith('{') || t.startsWith('['))) return true;

    // `stripFences` only strips a *leading* fence, so a model that writes a
    // sentence before opening a fenced block (e.g. "Here's your data:\n```json\n{...")
    // falls through to here. Cheaply check for a ``` fence opened anywhere
    // in the streamed-so-far text that hasn't been closed yet — that's a
    // strong signal a payload is arriving inside it, without re-scanning or
    // parsing the whole string on every frame.
    final openFence = partialText.indexOf('```');
    if (openFence == -1) return false;
    final closeFence = partialText.indexOf('```', openFence + 3);
    return closeFence == -1;
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

  // Structural children are a tree-shape signal, not a semantic content
  // value like `title` — so unlike other props they must NOT go through
  // A2UiProps.lookup's alias resolution. `keyAliases['children']` includes
  // `items` as a convenience alias, but `items` is also DataListGroup's own
  // canonical key for its (non-component) data rows; resolving it there
  // would make the parser mistake a DataListGroup's `items` list for child
  // nodes, fail to parse any of them as components, and then discard the
  // whole node as if it had declared-but-empty children. `_childKeys` checks
  // a fixed, literal set of keys instead — the same tolerant spelling
  // `_envelopeKeys` already accepts at the top level (`components`/
  // `elements`/`content` alongside `children`), while still deliberately
  // excluding `items`, which is the one key that actually collides.
  List<A2UiNode> _parseChildren(A2UiProps props) {
    final raw = _firstChildList(props.raw);
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
      _firstChildList(props) is List;

  /// Returns the value of the first key in `_childKeys` present in [props],
  /// or null if none of them are — a literal, non-alias-resolved lookup.
  Object? _firstChildList(Map<String, Object?> props) {
    for (final key in _childKeys) {
      final value = props[key];
      if (value != null) return value;
    }
    return null;
  }

  /// Wraps [items] in a `GridContainer`, dropping any item that isn't a
  /// recognised component. When [collapseSingle] is true, a single
  /// surviving child is returned bare instead of wrapped — used for the
  /// bare top-level array case, where a one-item array is ambiguous
  /// between "a list with one component" and "just a component". Envelope
  /// keys (`components`, `children`, `ui`, `elements`) pass
  /// `collapseSingle: false` because naming an envelope key is an explicit
  /// request for a container, even with one child.
  A2UiNode? _wrap(
    List<Object?> items, {
    int columns = 1,
    required bool collapseSingle,
  }) {
    final children = <A2UiNode>[];
    for (final item in items) {
      if (item is! Map) continue;
      final node = parseJson(A2UiProps.stringKeyed(item));
      if (node != null) children.add(node);
    }
    if (children.isEmpty) return null;
    if (collapseSingle && children.length == 1) return children.single;
    return A2UiNode(
      name: _containerName,
      props: A2UiProps({'columns': columns}),
      children: children,
    );
  }

  /// Pulls a JSON object or array out of [text], tolerating fences and
  /// surrounding prose. Returns null when nothing decodes.
  ///
  /// Rather than slicing from the first `{`/`[` to the last `}`/`]` in the
  /// whole text (which breaks the moment prose contains any stray brace,
  /// e.g. "add reps {optional}"), this scans every position that could
  /// start a JSON value, walks forward with a bracket-depth counter that
  /// tracks whether it's inside a string literal (so quoted brackets don't
  /// affect balance and `\"` doesn't end a string early), and attempts
  /// `jsonDecode` on each balanced span found. Among all spans that decode
  /// successfully to a Map or List, the longest one wins: the actual
  /// payload is normally the largest well-formed JSON structure in the
  /// text, while incidental prose braces either fail to decode (not valid
  /// JSON) or are short.
  static Object? _extractJson(String text) {
    final t = stripFences(text);
    if (t.isEmpty) return null;

    // Fast path: the common case is a reply that's nothing but JSON, with no
    // surrounding prose. Trying the whole trimmed text first avoids the
    // per-position balanced-span scan below for that case; it changes no
    // behaviour, since a fully-decodable whole string is always the longest
    // possible candidate the scan could have found anyway.
    try {
      final whole = jsonDecode(t);
      if (whole is Map || whole is List) return whole;
    } catch (_) {
      // Not decodable as-is — fall through to the scan for prose-wrapped JSON.
    }

    String? bestCandidate;
    Object? bestValue;

    for (var i = 0; i < t.length; i++) {
      final ch = t[i];
      if (ch != '{' && ch != '[') continue;
      final end = _findBalancedEnd(t, i);
      if (end == -1) continue;

      final candidate = t.substring(i, end + 1);
      Object? decoded;
      try {
        decoded = jsonDecode(candidate);
      } catch (_) {
        continue;
      }
      if (decoded is! Map && decoded is! List) continue;

      if (bestCandidate == null || candidate.length > bestCandidate.length) {
        bestCandidate = candidate;
        bestValue = decoded;
      }
    }

    return bestValue;
  }

  /// Returns the index of the character that closes the bracket opened at
  /// [start] (a `{` or `[`), or -1 if the text ends before it balances.
  /// Characters inside a `"..."` string literal never affect the depth
  /// count, and a `\` inside a string escapes the next character so `\"`
  /// doesn't end the string early.
  static int _findBalancedEnd(String t, int start) {
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = start; i < t.length; i++) {
      final ch = t[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (ch == '\\') {
          escaped = true;
        } else if (ch == '"') {
          inString = false;
        }
        continue;
      }
      if (ch == '"') {
        inString = true;
        continue;
      }
      if (ch == '{' || ch == '[') {
        depth++;
      } else if (ch == '}' || ch == ']') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }
}
