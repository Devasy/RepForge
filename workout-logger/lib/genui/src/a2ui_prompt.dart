import 'dart:convert';

import 'a2ui_registry.dart';

/// Builds the A2UI instruction block for an LLM system prompt.
///
/// Generated from [registry] rather than hand-written, so a schema change in a
/// spec reaches the model automatically and the vocabulary advertised can never
/// exceed the vocabulary the renderer supports.
///
/// Output is deterministic for a given registry so it can sit inside a cached
/// prompt prefix.
String buildA2UiPromptSection(A2UiRegistry registry, {String? envelopeNote}) {
  final buf = StringBuffer()
    ..writeln(
      'To answer with a visual dashboard instead of prose, return ONE JSON '
      'object and nothing else — no Markdown fence, no commentary before or '
      'after. Wrap multiple components in a GridContainer.',
    )
    ..writeln()
    ..writeln('Envelope: {"component": "<Name>", "props": { ... }}')
    ..writeln();

  if (envelopeNote != null && envelopeNote.isNotEmpty) {
    buf
      ..writeln(envelopeNote)
      ..writeln();
  }

  buf.writeln('AVAILABLE COMPONENTS — use these names and props only:');
  for (final spec in registry.specs) {
    buf
      ..writeln('  ${spec.doc.schema}')
      ..writeln('      ${spec.doc.purpose}');
  }

  buf
    ..writeln()
    ..writeln('WORKED EXAMPLE:')
    ..writeln(_example(registry))
    ..writeln()
    ..writeln(
      'TOLERANCES — you do not need to be perfect: a number may be sent as a '
      'number or a numeric string, prop names are matched ignoring case and '
      'underscores, unknown props are ignored, and any prop marked ? may be '
      'omitted. Prefer real numbers and the exact names above.',
    )
    ..writeln(
      'Never invent a component name that is not listed. If you have no data '
      'to show, reply in prose instead of returning an empty dashboard.',
    );

  return buf.toString();
}

/// A GridContainer wrapping the first two non-container examples, pretty-printed
/// so the model sees the nesting clearly.
String _example(A2UiRegistry registry) {
  final children = [
    for (final spec in registry.specs)
      if (spec.name != 'GridContainer') spec.doc.example,
  ].take(2).toList();

  return const JsonEncoder.withIndent('  ').convert({
    'component': 'GridContainer',
    'props': {'columns': 2, 'children': children},
  });
}
