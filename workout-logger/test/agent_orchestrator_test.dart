// Unit tests for AgentOrchestrator

import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart'
    show Content, Tool, FunctionCall;
import 'package:repforge/services/interfaces/ai_service_interface.dart';
import 'package:repforge/services/ai/agent_event.dart';
import 'package:repforge/services/ai/agent_orchestrator.dart';
import 'package:repforge/models/models.dart';

class _MockAiService implements IAiService {
  _MockAiService({required this.roundsResponse});

  final List<List<dynamic>> roundsResponse; // dynamic is String or FunctionCall
  int currentRound = 0;
  List<String> userMessagesReceived = [];
  List<List<Content>> historiesReceived = [];

  @override
  bool get isConfigured => true;

  @override
  String get currentModel => 'mock';

  @override
  Stream<String> streamCoachReply({
    required String userMessage,
    required String systemPrompt,
    required List<Content> history,
    List<Tool>? tools,
    Future<Map<String, Object?>> Function(FunctionCall call)? onToolCall,
  }) async* {
    userMessagesReceived.add(userMessage);
    historiesReceived.add(List<Content>.from(history));

    if (currentRound >= roundsResponse.length) {
      yield 'Mock done';
      return;
    }

    final responses = roundsResponse[currentRound];
    currentRound++;

    for (final r in responses) {
      if (r is FunctionCall) {
        if (onToolCall != null) {
          await onToolCall(r);
        }
      } else if (r is String) {
        yield r;
      }
    }
  }

  @override
  Future<TrainingProgram> generateProgram({
    required String userPrompt,
    required List<Exercise> allExercises,
  }) =>
      throw UnimplementedError();

  @override
  Future<String> generateWeeklyInsights(String contextText) =>
      throw UnimplementedError();

  @override
  Future<String> generateInsight(String system, String context) =>
      throw UnimplementedError();
}

void main() {
  group('AgentOrchestrator', () {
    test('orchestrate yields text and wrap tool events', () async {
      final ai = _MockAiService(
        roundsResponse: [
          [
            FunctionCall('get_muscle_recovery', {}),
            'You are recovering well.',
          ]
        ],
      );
      final orchestrator = AgentOrchestrator(ai: ai);
      final events = <AgentEvent>[];

      await for (final event in orchestrator.orchestrate(
        userMessage: 'How is my recovery?',
        systemPrompt: 'System',
        history: [],
        tools: [],
        onToolCall: (_) async => {'status': 'recovered'},
      )) {
        events.add(event);
      }

      expect(ai.currentRound, 1);
      expect(events[0], isA<AgentStatusUpdate>()); // Thinking…
      expect(events[1], isA<AgentToolActivity>()); // recovery tool start
      expect((events[1] as AgentToolActivity).isStart, isTrue);
      expect(events[2], isA<AgentStatusUpdate>()); // Fetching Muscle recovery status…
      expect(events[3], isA<AgentToolActivity>()); // recovery tool end
      expect((events[3] as AgentToolActivity).isStart, isFalse);
      expect(events[4], isA<AgentTextChunk>());
      expect((events[4] as AgentTextChunk).text, 'You are recovering well.');
    });

    test('orchestrate triggers second round if progress query has no tools used',
        () async {
      final ai = _MockAiService(
        roundsResponse: [
          // Round 0: text reply only (no tool call)
          ['You look progress.'],
          // Round 1: normal reply after prompt
          ['After fetching bench, progress is 10%.'],
        ],
      );
      final orchestrator = AgentOrchestrator(ai: ai);
      final events = <AgentEvent>[];

      await for (final event in orchestrator.orchestrate(
        userMessage: 'how is my bench press progress?',
        systemPrompt: 'System',
        history: [],
        tools: [],
        onToolCall: (_) async => {},
        maxRounds: 2,
      )) {
        events.add(event);
      }

      expect(ai.currentRound, 2);
      expect(ai.userMessagesReceived[0], 'how is my bench press progress?');
      // Second user message should be the orchestrator feedback prompt
      expect(ai.userMessagesReceived[1], contains('did not query their actual logged workouts'));

      // Check events containing spacer and status updates
      expect(events.any((e) => e is AgentStatusUpdate && e.status.contains('Analyzing further')), isTrue);
      expect(events.any((e) => e is AgentTextChunk && e.text == '\n\n'), isTrue);
      expect(events.last, isA<AgentTextChunk>());
      expect((events.last as AgentTextChunk).text, 'After fetching bench, progress is 10%.');
    });
  });
}
