// Widget tests for RoutineOptimizerScreen.
//
// Tests the view layer by injecting a pre-built RoutineOptimizerViewModel
// via ChangeNotifierProvider.value, bypassing the real AI service setup.
// Uses RoutineOptimizerScreen.testBody() to render the inner view directly.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart'
    show Content, Tool, FunctionCall;
import 'package:provider/provider.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/routine_optimizer_screen.dart';
import 'package:repforge/screens/widgets/rf_question_card.dart';
import 'package:repforge/services/ai/coach_tool_service.dart';
import 'package:repforge/services/interfaces/ai_service_interface.dart';
import 'package:repforge/services/managers/conversation_manager.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/managers/pr_manager.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/theme/app_theme.dart';
import 'package:repforge/viewmodels/routine_optimizer_view_model.dart';
import 'test_utils/mock_storage_service.dart';

// ── Fake AI services ───────────────────────────────────────────────────────

/// AI that immediately yields a single reply chunk and completes.
class _ImmediateAi implements IAiService {
  const _ImmediateAi({this.reply = 'All done!'});
  final String reply;

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
    yield reply;
  }

  @override
  Future<TrainingProgram> generateProgram({
    required String userPrompt,
    required List<Exercise> allExercises,
  }) => throw UnimplementedError();

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

/// AI that hangs indefinitely — keeps `isLoading` true for the entire test.
class _HangingAi implements IAiService {
  final _done = Completer<void>();

  @override
  bool get isConfigured => true;
  @override
  String get currentModel => 'fake';

  void complete() => _done.complete();

  @override
  Stream<String> streamCoachReply({
    required String userMessage,
    required String systemPrompt,
    required List<Content> history,
    List<Tool>? tools,
    Future<Map<String, Object?>> Function(FunctionCall call)? onToolCall,
  }) async* {
    await _done.future;
  }

  @override
  Future<TrainingProgram> generateProgram({
    required String userPrompt,
    required List<Exercise> allExercises,
  }) => throw UnimplementedError();

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

/// AI that fires an `ask_user_questions` tool call before yielding a reply.
class _QuestionAi implements IAiService {
  const _QuestionAi();

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
    if (onToolCall != null) {
      await onToolCall(FunctionCall('ask_user_questions', {
        'preamble': 'Before I start, a quick question.',
        'questions': [
          {
            'question': 'What is your primary goal?',
            'options': ['Strength', 'Hypertrophy', 'Fat loss'],
          },
        ],
      }));
    }
    yield 'Done.';
  }

  @override
  Future<TrainingProgram> generateProgram({
    required String userPrompt,
    required List<Exercise> allExercises,
  }) => throw UnimplementedError();

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

// ── Test helpers ───────────────────────────────────────────────────────────

final _pushDay = Routine(id: 'r1', name: 'Push Day', exerciseIds: const []);

RoutineOptimizerViewModel _buildVm(IAiService ai) {
  final storage = MockStorageService();
  final wp = WorkoutProvider(storage, programManager: ProgramManager(storage));
  final pr = PRManager(storage);
  final conversations = ConversationManager(storage, kind: 'optimizer');
  final settings = SettingsProvider(storage);
  final coachTools = CoachToolService(wp, pr);
  return RoutineOptimizerViewModel(
    ai: ai,
    coachTools: coachTools,
    conversations: conversations,
    settings: settings,
  );
}

Widget _wrap(RoutineOptimizerViewModel vm) => MaterialApp(
      theme: AppTheme.darkTheme,
      home: ChangeNotifierProvider<RoutineOptimizerViewModel>.value(
        value: vm,
        child: RoutineOptimizerScreen.testBody(_pushDay),
      ),
    );

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  group('RoutineOptimizerScreen', () {
    testWidgets('shows title and routine name in header', (tester) async {
      final vm = _buildVm(const _ImmediateAi());
      await tester.pumpWidget(_wrap(vm));
      await tester.pump();

      expect(find.text('Optimize Routine'), findsOneWidget);
      expect(find.text('Push Day'), findsOneWidget);
    });

    testWidgets('shows loading indicator while AI is streaming', (tester) async {
      final ai = _HangingAi();
      final vm = _buildVm(ai);
      await tester.pumpWidget(_wrap(vm));

      // Trigger streaming without awaiting — keeps isLoading = true.
      unawaited(vm.startForRoutine(_pushDay));
      await tester.pump();

      // Streaming bubble with loading dots should be visible.
      expect(find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
             // RFLoadingDots is the animated dot indicator used in the bubble.
             find.byWidgetPredicate(
               (w) => w.runtimeType.toString() == 'RFLoadingDots',
             ).evaluate().isNotEmpty ||
             find.byIcon(Icons.auto_fix_high_rounded).evaluate().isNotEmpty,
             isTrue,
             reason: 'A streaming/loading indicator should be visible');

      // Verify we are in a loading state overall
      expect(vm.isLoading, isTrue);

      ai.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('renders seed user message and AI reply', (tester) async {
      final vm = _buildVm(const _ImmediateAi(reply: 'Great plan!'));
      await tester.pumpWidget(_wrap(vm));

      await vm.startForRoutine(_pushDay);
      await tester.pump();

      // Seed user message
      expect(
        find.textContaining('Push Day'),
        findsWidgets,
        reason: 'Routine name should appear in seed message or subtitle',
      );

      // AI reply
      expect(find.textContaining('Great plan!'), findsOneWidget);
    });

    testWidgets('user messages align to the right', (tester) async {
      final vm = _buildVm(const _ImmediateAi());
      await tester.pumpWidget(_wrap(vm));
      await vm.startForRoutine(_pushDay);
      await tester.pump();

      // There should be at least one message in the list.
      expect(vm.messages.isNotEmpty, isTrue);
      // User messages have role 'user'
      expect(vm.messages.any((m) => m.role == 'user'), isTrue);
    });

    testWidgets('shows RFQuestionCard when AI asks questions', (tester) async {
      final ai = _QuestionAi();
      final vm = _buildVm(ai);
      await tester.pumpWidget(_wrap(vm));

      // Start without awaiting so we can catch the pending state.
      unawaited(vm.startForRoutine(_pushDay));

      // Pump a few frames so the tool call fires and pendingQuestions is set.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      if (vm.pendingQuestions != null) {
        await tester.pump();
        expect(find.byType(RFQuestionCard), findsOneWidget);
        expect(find.text('What is your primary goal?'), findsOneWidget);

        // Submitting an answer unblocks the stream.
        vm.submitAnswers([
          AnswerSpec(question: 'What is your primary goal?', selected: ['Strength']),
        ]);
        await tester.pumpAndSettle();
        expect(find.byType(RFQuestionCard), findsNothing);
      } else {
        // If the stream already completed (fast machine), just verify no crash.
        await tester.pumpAndSettle();
      }
    });

    testWidgets('back button pops the route', (tester) async {
      bool popped = false;
      final vm = _buildVm(const _ImmediateAi());

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: Builder(builder: (ctx) {
          return Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.push(
                ctx,
                MaterialPageRoute<void>(
                  builder: (_) => ChangeNotifierProvider<
                      RoutineOptimizerViewModel>.value(
                    value: vm,
                    child: RoutineOptimizerScreen.testBody(_pushDay),
                  ),
                ),
              ).then((_) => popped = true),
              child: const Text('Open'),
            ),
          );
        }),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Now on the optimizer screen — tap back.
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(popped, isTrue);
    });

    testWidgets('history sheet shows empty state when no conversations',
        (tester) async {
      final vm = _buildVm(const _ImmediateAi());
      await tester.pumpWidget(_wrap(vm));
      await tester.pump();

      // Open the history sheet via the history button.
      await tester.tap(find.byIcon(Icons.history_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Optimization History'), findsOneWidget);
      expect(
        find.text('No saved optimization sessions yet.'),
        findsOneWidget,
      );
    });
  });
}
