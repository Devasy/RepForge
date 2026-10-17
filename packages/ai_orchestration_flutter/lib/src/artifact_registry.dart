import 'package:ai_orchestration/ai_orchestration.dart';
import 'package:flutter/widgets.dart';

typedef ArtifactWidgetBuilder =
    Widget Function(BuildContext context, Artifact artifact);
typedef ArtifactFallbackBuilder =
    Widget Function(
      BuildContext context,
      Artifact artifact,
      ArtifactRenderIssue issue,
    );

enum ArtifactRenderIssue { unsupportedTypeOrVersion, invalidPayload }

class ArtifactRenderer {
  final String type;
  final int version;
  final ValueSchema payloadSchema;
  final ArtifactWidgetBuilder builder;
  ArtifactRenderer({
    required this.type,
    this.version = 1,
    required this.payloadSchema,
    required this.builder,
  }) {
    if (type.isEmpty ||
        version < 1 ||
        payloadSchema.definition['type'] != 'object') {
      throw ArgumentError(
        'Renderers require a type, positive version and object schema.',
      );
    }
  }
}

class ArtifactRegistry {
  final Map<(String, int), ArtifactRenderer> _renderers = {};
  final ArtifactFallbackBuilder? fallbackBuilder;
  ArtifactRegistry(
    Iterable<ArtifactRenderer> renderers, {
    this.fallbackBuilder,
  }) {
    for (final renderer in renderers) {
      final key = (renderer.type, renderer.version);
      if (_renderers.containsKey(key)) {
        throw ArgumentError('Duplicate artifact renderer: $key');
      }
      _renderers[key] = renderer;
    }
  }

  Widget build(BuildContext context, Artifact artifact) {
    final renderer = _renderers[(artifact.type, artifact.version)];
    if (renderer == null) {
      return _fallback(
        context,
        artifact,
        ArtifactRenderIssue.unsupportedTypeOrVersion,
      );
    }
    try {
      renderer.payloadSchema.validate(artifact.payload);
    } on OrchestrationException {
      return _fallback(context, artifact, ArtifactRenderIssue.invalidPayload);
    }
    return renderer.builder(context, artifact);
  }

  Widget _fallback(
    BuildContext context,
    Artifact artifact,
    ArtifactRenderIssue issue,
  ) =>
      fallbackBuilder?.call(context, artifact, issue) ??
      const Text('This content cannot be displayed.');
}

class AgentArtifactView extends StatelessWidget {
  final Artifact artifact;
  final ArtifactRegistry registry;
  const AgentArtifactView({
    super.key,
    required this.artifact,
    required this.registry,
  });
  @override
  Widget build(BuildContext context) => registry.build(context, artifact);
}
