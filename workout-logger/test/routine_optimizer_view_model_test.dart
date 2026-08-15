// Unit tests for RoutineOptimizerViewModel

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart'
    show Content, Tool, FunctionCall;
import 'package:repforge/models/models.dart';
import 'package:repforge/services/interfaces/ai_service_interface.dart';
import 'package:repforge/services/ai/coach_tool_service.dart';
import 'package:repforge/services/managers/conversation_manager.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/managers/pr_manager.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/viewmodels/routine_optimizer_view_model.dart';
import 'test_utils/mock_storage_service.dart';

// ── Fake IAiService ────────────────────────────────────────────────────────

class _SimpleAi implements IAiService {
  _SimpleAi({this.chunks = const ['Done.'], this.toolCall});

  final List<String> chunks;
  final FunctionCall? toolCall;
  int calls = 0;

  @override
  bool get isConfigured => true;
  @override
  String get currentModel => 'fake';

  @override
  Stream<String> streamCoachReply({
    required String userMessage,
    required String systemPrompt,
    required List<Content> history,
    List<Tool>? tools,
    Future<Map<String, Object?>> Function(FunctionCall call)? onToolCall,
  }) async* {
    calls++;
    final tc = toolCall;
    if (tc != null && onToolCall != null) {
      await onToolCall(tc);
    }
    for (final c in chunks) {
      yield c;
    }
  }

  @override
  Future<TrainingProgram> generateProgram({
    required String userPrompt,
    required List<Exercise> allExercises,
  }) =>
      throw UnimplementedError();

  @override
  Future<String> generateWeeklyInsights(String contextText) async => '';

  @override
  Future<String> generateInsight(String system, String context) async => '';

  @override
  Stream<String> streamChatReply({
    required String userMessage,
    required String systemPrompt,
    required List<Content> history,
    List<Tool>? tools,
    Future<Map<String, Object?>> Function(FunctionCall call)? onToolCall,
  }) =>
      streamCoachReply(
        userMessage: userMessage,
        systemPrompt: systemPrompt,
        history: history,
        tools: tools,
        onToolCall: onToolCall,
      );

  @override
  Future<T> generateStructuredJson<T>({
    required String systemPrompt,
    required String userPrompt,
    required T Function(Map<String, dynamic> json) fromJson,
  }) =>
      throw UnimplementedError();
}

class _ThrowingAi implements IAiService {
  @override
  bool get isConfigured => true;
  @override
  String get currentModel => 'fake';

  @override
  Stream<String> streamCoachReply({
    required String userMessage,
    required String systemPrompt,
    required List<Content> history,
    List<Tool>? tools,
    Future<Map<String, Object?>> Function(FunctionCall call)? onToolCall,
  }) async* {
    throw Exception('Network error');
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

  @override
  Stream<String> streamChatReply({
    required String userMessage,
    required String systemPrompt,
    required List<Content> history,
    List<Tool>? tools,
    Future<Map<String, Object?>> Function(FunctionCall call)? onToolCall,
  }) =>
      streamCoachReply(
        userMessage: userMessage,
        systemPrompt: systemPrompt,
        history: history,
        tools: tools,
        onToolCall: onToolCall,
      );

  @override
  Future<T> generateStructuredJson<T>({
    required String systemPrompt,
    required String userPrompt,
    required T Function(Map<String, dynamic> json) fromJson,
  }) =>
      throw UnimplementedError();
}

// ── Helper ────────────────────────────────────────────────────────────────

RoutineOptimizerViewModel _buildVm({
  required MockStorageService storage,
  required IAiService ai,
}) {
  final wp = WorkoutProvider(storage, programManager: ProgramManager(storage));
  final pr = PRManager(storage);
  final conversations = ConversationManager(storage, kind: 'optimizer');
  final settings = SettingsProvider(storage);
  final coachTools = CoachToolService(workoutProvider: wp, prManager: pr);
  return RoutineOptimizerViewModel(
    ai: ai,
    coachTools: coachTools,
    conversations: conversations,
    settings: settings,
  );
}

final _routine = Routine(id: 'r1', name: 'Push Day', exerciseIds: const []);

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  late MockStorageService storage;
  setUp(() => storage = MockStorageService());

  group('RoutineOptimizerViewModel', () {
    test('startForRoutine auto-sends seed message', () async {
      final ai = _SimpleAi();
      final vm = _buildVm(storage: storage, ai: ai);
      await vm.startForRoutine(_routine);
      expect(ai.calls, 1);
      expect(vm.messages.length, greaterThanOrEqualTo(2));
      expect(vm.messages.first.role, 'user');
      expect(vm.messages.first.text, contains('Push Day'));
    });

    test('isLoading is true during streaming and false after', () async {
      final ai = _SimpleAi(chunks: ['chunk']);
      final vm = _buildVm(storage: storage, ai: ai);
      bool wasLoading = false;
      vm.addListener(() {
        if (vm.isLoading) wasLoading = true;
      });
      await vm.startForRoutine(_routine);
      expect(wasLoading, isTrue);
      expect(vm.isLoading, isFalse);
    });

    test('ask_user_questions sets pendingQuestions mid-stream', () async {
      final questionCall = FunctionCall('ask_user_questions', {
        'preamble': 'Quick question.',
        'questions': [
          {
            'question': 'Your goal?',
            'options': ['Strength', 'Hypertrophy'],
          },
        ],
      });

      PendingQuestions? captured;

      final ai = _SimpleAi(chunks: ['Applied.'], toolCall: questionCall);
      final vm = _buildVm(storage: storage, ai: ai);

      vm.addListener(() async {
        if (vm.pendingQuestions != null && captured == null) {
          captured = vm.pendingQuestions;
          // Submit to unblock the stream
          await vm.submitAnswers([
            AnswerSpec(question: 'Your goal?', selected: ['Strength']),
          ]);
        }
      });

      await vm.startForRoutine(_routine);
      expect(captured?.questions.first.question, 'Your goal?');
    });

    test('submitAnswers persists answers as a user message', () async {
      bool questionsSeen = false;
      final questionCall = FunctionCall('ask_user_questions', {
        'questions': [
          {'question': 'Goal?', 'options': ['Strength']},
        ],
      });
      final ai = _SimpleAi(chunks: ['Done.'], toolCall: questionCall);
      final vm = _buildVm(storage: storage, ai: ai);

      vm.addListener(() async {
        if (vm.pendingQuestions != null && !questionsSeen) {
          questionsSeen = true;
          await vm.submitAnswers([
            AnswerSpec(question: 'Goal?', selected: ['Strength']),
          ]);
        }
      });

      await vm.startForRoutine(_routine);

      final userMessages = vm.messages.where((m) => m.role == 'user').toList();
      expect(userMessages.any((m) => m.text.contains('Strength')), isTrue);
    });

    test('stream error appends error message and clears loading', () async {
      final vm = _buildVm(storage: storage, ai: _ThrowingAi());
      await vm.startForRoutine(_routine);
      expect(vm.isLoading, isFalse);
      expect(vm.pendingQuestions, isNull);
      final modelMsgs = vm.messages.where((m) => m.role == 'model').toList();
      expect(modelMsgs.any((m) => m.text.contains('Error')), isTrue);
    });

    test('dispose completes pending Completer without leaking', () async {
      final questionCall = FunctionCall('ask_user_questions', {
        'questions': [
          {'question': 'Goal?', 'options': ['Strength']},
        ],
      });
      final ai = _SimpleAi(chunks: ['Done.'], toolCall: questionCall);
      final vm = _buildVm(storage: storage, ai: ai);

      // Start but DON'T submit answers
      // We need to ensure dispose() doesn't hang
      final future = vm.startForRoutine(_routine);
      await Future<void>.delayed(Duration.zero); // let it start

      // If pendingQuestions is set, dispose should complete the completer
      vm.dispose();

      // The future should complete (not hang) after dispose
      await future.timeout(const Duration(seconds: 2));
      expect(vm.pendingQuestions, isNull);
    });
  });
}
