import 'package:repforge/services/ai/provider/model_message.dart';
import 'package:repforge/services/ai/provider/model_runtime.dart';
import 'package:repforge/services/ai/provider/model_step.dart';
import 'package:repforge/services/ai/provider/provider_metadata.dart';
import 'package:repforge/services/ai/tools/tool_spec.dart';

class FakeModelRuntime implements ModelRuntime {
  FakeModelRuntime({
    this.steps = const [
      ModelTextDelta('Hello '),
      ModelTextDelta('world'),
      ModelFinish('stop'),
    ],
  });

  final List<ModelStep> steps;

  @override
  bool get isConfigured => true;

  @override
  String get currentModel => 'fake-model';

  @override
  ProviderMetadata get metadata => const ProviderMetadata(
        providerId: 'fake',
        modelId: 'fake-model',
      );

  @override
  Stream<ModelStep> streamStep({
    required String systemPrompt,
    required List<ModelMessage> messages,
    required List<ToolSpec> tools,
  }) async* {
    for (final step in steps) {
      yield step;
    }
  }
}
