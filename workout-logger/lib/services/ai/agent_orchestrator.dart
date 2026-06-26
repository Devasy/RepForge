// agent_orchestrator.dart — Iterative agent loop for the AI coach/optimizer.
//
// Wraps IAiService.streamCoachReply with an outer orchestration layer that:
// 1. Sends the user message to the model with tools.
// 2. The model may call tools — results are fed back (handled by IAiService).
// 3. After the model replies, the orchestrator inspects the response:
//    - Did the model actually use the available tools, or did it just guess?
//    - Is the response substantive, or a shallow one-liner?
// 4. If the response seems incomplete, the orchestrator can re-prompt the model
//    with a hint to use more tools or elaborate.
// 5. Yields AgentEvent throughout so the UI shows exactly what's happening.
//
// This is the "agent brain" that makes responses feel thorough and considered
// rather than half-baked single-shot answers.

import 'dart:async';

import 'package:google_generative_ai/google_generative_ai.dart'
    show Content, FunctionCall, Tool, TextPart;

import '../interfaces/ai_service_interface.dart';
import 'agent_event.dart';

/// Human-readable labels for tool calls, derived from tool name + arguments.
String _toolLabel(FunctionCall call) {
  switch (call.name) {
    case 'get_exercise_performance':
      final name = call.args['exercise_name'] as String? ?? 'exercise';
      return '$name performance';
    case 'get_workouts_in_range':
      final days = call.args['days'];
      return days != null ? 'Workouts (last ${days}d)' : 'Workout history';
    case 'get_routine_performance':
      final name = call.args['routine_name'] as String? ?? 'routine';
      return '$name routine data';
    case 'get_personal_records':
      final name = call.args['exercise_name'] as String?;
      return name != null ? '$name PR' : 'All personal records';
    case 'get_goal_progress':
      return 'Goal progress';
    case 'get_muscle_recovery':
      return 'Muscle recovery status';
    case 'get_all_routines':
      return 'All routines';
    case 'create_routine':
      final name = call.args['name'] as String? ?? 'routine';
      return 'Creating "$name"';
    case 'update_routine':
      final name = call.args['routine_name'] as String? ?? 'routine';
      return 'Updating "$name"';
    case 'add_custom_exercise':
      final name = call.args['name'] as String? ?? 'exercise';
      return 'Adding "$name"';
    case 'ask_user_questions':
      return 'Preparing questions';
    default:
      return call.name;
  }
}

/// The iterative agent orchestrator.
///
/// Instead of a single pass through `streamCoachReply`, this orchestrator
/// wraps the call and emits rich [AgentEvent]s. It tracks which tools were
/// called and can detect shallow responses.
///
/// The actual tool-call loop (model calls tool → result fed back → model
/// continues) is already handled inside `IAiService.streamCoachReply`. This
/// orchestrator adds:
/// - Tool activity tracking (start/end events)
/// - Status updates for the UI
/// - Detection of "the model didn't use tools when it should have"
/// - Future: multi-round re-prompting
class AgentOrchestrator {
  final IAiService _ai;

  AgentOrchestrator({required IAiService ai}) : _ai = ai;

  /// Whether the underlying AI service has been configured (API key set).
  bool get isConfigured => _ai.isConfigured;

  /// Run the full agent loop, yielding [AgentEvent]s.
  ///
  /// [onToolCall] is the handler for tool calls (from CoachToolService).
  /// The orchestrator wraps it to emit tool activity events.
  ///
  /// [maxRounds] limits how many re-prompting rounds the orchestrator will
  /// attempt if the model gives a shallow response.
  Stream<AgentEvent> orchestrate({
    required String userMessage,
    required String systemPrompt,
    required List<Content> history,
    required List<Tool> tools,
    required Future<Map<String, Object?>> Function(FunctionCall call) onToolCall,
    int maxRounds = 3,
  }) async* {
    yield const AgentStatusUpdate('Thinking…');

    final currentHistory = List<Content>.from(history);
    var currentUserMessage = userMessage;

    for (var round = 0; round < maxRounds; round++) {
      final toolsUsed = <String>[];
      final toolCallLog = <_ToolCallRecord>[];
      final currentRoundTextBuffer = StringBuffer();

      // Since we can't yield from within a closure passed to streamCoachReply,
      // we use a StreamController to merge tool events with text events.
      final controller = StreamController<AgentEvent>();
      var isClosed = false;

      void safeAdd(AgentEvent event) {
        if (!isClosed) controller.add(event);
      }

      // Wrapped tool handler that emits events through the controller.
      Future<Map<String, Object?>> instrumentedToolCall(FunctionCall call) async {
        final label = _toolLabel(call);
        toolsUsed.add(call.name);
        toolCallLog.add(_ToolCallRecord(call.name, label));

        safeAdd(AgentToolActivity(call.name, isStart: true, label: label));
        safeAdd(AgentStatusUpdate('Fetching $label…'));

        try {
          final result = await onToolCall(call);
          safeAdd(AgentToolActivity(call.name, isStart: false, label: label));
          return result;
        } catch (e) {
          safeAdd(AgentToolActivity(call.name, isStart: false, label: label));
          safeAdd(AgentStatusUpdate('Error fetching $label'));
          rethrow;
        }
      }

      // Run the streaming call in a separate zone, piping events into the
      // controller. This lets tool activity events interleave with text chunks.
      final streamFuture = () async {
        try {
          await for (final chunk in _ai.streamCoachReply(
            userMessage: currentUserMessage,
            systemPrompt: systemPrompt,
            history: currentHistory,
            tools: tools,
            onToolCall: instrumentedToolCall,
          )) {
            currentRoundTextBuffer.write(chunk);
            safeAdd(AgentTextChunk(chunk));
          }
        } catch (e) {
          safeAdd(AgentError('$e'));
        } finally {
          if (!isClosed) {
            isClosed = true;
            await controller.close();
          }
        }
      }();

      // Yield events from the controller as they arrive.
      yield* controller.stream;

      // Ensure the stream future completes.
      await streamFuture;

      final roundReply = currentRoundTextBuffer.toString().trim();

      // Check if we need another round: did the user ask a query that needs
      // tools, but the model didn't call any tools?
      final queryNeedsTools = _queryRequiresTools(userMessage);
      if (queryNeedsTools && toolsUsed.isEmpty && round < maxRounds - 1) {
        // Model failed to use tools. Update history and feedback prompt.
        currentHistory.add(Content.text(currentUserMessage));
        currentHistory.add(Content.model([TextPart(roundReply)]));

        currentUserMessage = 'You are answering a query about the user\'s progress or history, '
            'but you did not query their actual logged workouts. Please use the relevant tools '
            '(e.g. get_exercise_performance, get_workouts_in_range, get_personal_records) '
            'to retrieve the user\'s real data before answering.';

        yield const AgentStatusUpdate('Analyzing further with database tools…');
        yield const AgentTextChunk('\n\n'); // Spacer between attempts
        continue;
      }

      break;
    }
  }

  bool _queryRequiresTools(String query) {
    final lower = query.toLowerCase();
    final progressKeywords = [
      'progress',
      'plateau',
      'history',
      'performance',
      'record',
      'goal',
      'compare',
      'bench',
      'squat',
      'deadlift',
      'weight',
      'volume',
      'routine',
      'recovery',
      'how am i doing',
      'what did i do',
      'optimize',
    ];
    return progressKeywords.any((k) => lower.contains(k));
  }
}

/// Internal record of a tool call for analysis.
class _ToolCallRecord {
  final String name;
  final String label;
  _ToolCallRecord(this.name, this.label);
}
