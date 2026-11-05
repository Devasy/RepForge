import 'dart:async';
import 'package:ai_orchestration/ai_orchestration.dart';
import 'package:uuid/uuid.dart';
import 'langfuse_service.dart';
import '../gemini_ai_service.dart';

class AgentTracing {
  AgentTracing(this.service, this.sessionId, {this.metadata = const {}});
  final LangfuseService service;
  final String sessionId;
  final Map<String, Object?> metadata;
  final traceId = const Uuid().v4().replaceAll('-', '');
  final rootSpanId = const Uuid().v4().replaceAll('-', '').substring(0, 16);
  final started = DateTime.now();
  Object? input, output;
  bool _finished = false;
  void begin() {
    _finished = false;
  }

  void finish({bool failed = false}) {
    if (_finished) return;
    _finished = true;
    try {
      service.record(
        traceId: traceId,
        sessionId: sessionId,
        name: 'Workout agent turn',
        type: 'agent',
        started: started,
        spanId: rootSpanId,
        input: input,
        output: output,
        metadata: metadata,
        failed: failed,
      );
    } catch (_) {
      // Trace finalization must not affect agent state.
    }
  }

  void record(
    String name,
    String type,
    DateTime started, {
    Object? input,
    Object? output,
    Map<String, Object?> details = const {},
    String? model,
    bool failed = false,
  }) {
    try {
      service.record(
        traceId: traceId,
        sessionId: sessionId,
        name: name,
        type: type,
        started: started,
        parentSpanId: rootSpanId,
        input: input,
        output: output,
        metadata: {...metadata, ...details},
        model: model,
        failed: failed,
      );
    } catch (_) {
      // Observability must never change agent execution.
    }
  }

  ToolRegistry tools(ToolRegistry original) => ToolRegistry([
    for (final definition in original.definitions)
      _TracedTool(original.require(definition.name), this),
  ]);
}

class TracedModel implements ModelProvider {
  TracedModel(this.inner, this.trace);
  final ModelProvider inner;
  final AgentTracing trace;
  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    trace.begin();
    if (trace.input == null && request.messages.isNotEmpty) {
      trace.input = request.messages.last.text;
    }
    final started = DateTime.now();
    final text = StringBuffer();
    final calls = <JsonMap>[];
    final statuses = <String>[];
    final transport = <JsonMap>[];
    JsonMap usage = {};
    String model = request.modelId;
    String? version, failure;
    var complete = false;
    try {
      final source = inner is GeminiAiService
          ? (inner as GeminiAiService).stream(
              request,
              cancellation,
              onDiagnostic: transport.add,
            )
          : inner.stream(request, cancellation);
      await for (final event in source) {
        if (event is ModelText) text.write(event.text);
        if (event is ModelStatus) statuses.add(event.message);
        if (event is ModelToolCall) calls.add(event.call.toJson());
        if (event is ModelFinished) {
          usage = event.usage;
          final gemini = event.providerData['gemini'];
          if (gemini is Map) {
            model = gemini['model'] as String? ?? model;
            version = gemini['modelVersion'] as String?;
          }
          complete = true;
        }
        yield event;
      }
    } catch (error) {
      failure = error is OrchestrationException
          ? error.code
          : error.runtimeType.toString();
      rethrow;
    } finally {
      trace.output = text.toString();
      if (!complete && transport.isNotEmpty) {
        final modelEvents = transport.where(
          (event) => event['model'] is String,
        );
        if (modelEvents.isNotEmpty) {
          model = modelEvents.last['model']! as String;
        }
      }
      trace.record(
        'Gemini reply',
        'generation',
        started,
        input: {
          'systemPrompt': request.systemPrompt,
          'messages': [
            for (final m in request.messages)
              {
                'role': m.role,
                'text': m.text,
                if (m.result != null) 'result': m.result,
                if (m.calls.isNotEmpty)
                  'calls': m.calls.map((c) => c.toJson()).toList(),
              },
          ],
        },
        output: {'text': text.toString(), 'calls': calls},
        model: version ?? model,
        details: {
          'requestedModel': request.modelId,
          'resolvedModel': model,
          'modelVersion': version,
          'usage': usage,
          'statuses': statuses,
          'completed': complete,
          'failure': failure,
          'promptVersion': 'coach-evidence-v3',
          'transport': transport,
          'toolNames': request.tools.map((tool) => tool.name).toList(),
        },
        failed: failure != null || !complete,
      );
    }
  }
}

class _TracedTool implements AgentTool {
  _TracedTool(this.inner, this.trace);
  final AgentTool inner;
  final AgentTracing trace;
  @override
  ToolDefinition get definition => inner.definition;
  @override
  Future<ToolOutcome> execute(ToolContext context) async {
    final started = DateTime.now();
    Object? output;
    var failed = false;
    try {
      final outcome = await inner.execute(context);
      if (outcome is ToolSuccess) {
        output = outcome.data;
        failed = outcome.data.containsKey('error');
      } else if (outcome is ToolNeedsInput) {
        output = {'needsInput': outcome.request.kind};
      }
      return outcome;
    } catch (error) {
      failed = true;
      output = {'errorType': error.runtimeType.toString()};
      rethrow;
    } finally {
      trace.record(
        definition.name,
        'tool',
        started,
        input: context.call.arguments,
        output: output,
        details: {
          'runId': context.runId,
          'callId': context.call.id,
          'effect': definition.effect.name,
          'modelCallIndex': context.modelCallIndex,
        },
        failed: failed,
      );
    }
  }
}
