/// A2UI — a domain-free, model-driven UI layer.
///
/// Parse untrusted LLM JSON with [A2UiParser], render the resulting
/// [A2UiNode] with [A2UiRenderer], and generate the model's instructions from
/// the same registry with `buildA2UiPromptSection`, so the vocabulary the model
/// is told about and the vocabulary the app can render never diverge.
library;

export 'src/a2ui_node.dart';
export 'src/a2ui_parser.dart';
export 'src/a2ui_prompt.dart';
export 'src/a2ui_props.dart';
export 'src/a2ui_registry.dart';
export 'src/a2ui_renderer.dart';
export 'src/a2ui_series.dart';
export 'src/a2ui_spec.dart';
export 'src/a2ui_theme.dart';
export 'src/default_registry.dart';
