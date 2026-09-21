// Unit tests for AiCoachViewModel — verifies orchestration (send → stream →
// persist) using a fake IAiService, so the View has no logic left to test.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart'
    show Content, Tool, FunctionCall, DataPart, TextPart, Part;
import 'package:repforge/models/models.dart';
import 'package:repforge/services/interfaces/ai_service_interface.dart';
import 'package:repforge/services/ai/coach_tool_service.dart';
import 'package:repforge/services/managers/conversation_manager.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/managers/pr_manager.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/viewmodels/ai_coach_view_model.dart';
import 'test_utils/mock_storage_service.dart';

/// Scripted IAiService: yields fixed chunks; optionally invokes a tool first.
class _FakeAiService implements IAiService {
  _FakeAiService({this.chunks = const ['Hello ', 'world'], this.invokeTool = false});

  final List<String> chunks;
  final bool invokeTool;
  int toolCallsMade = 0;
  String? lastImageBytesBase64;
  String? lastImageMimeType;
  List<Content>? lastHistory;

  @override
  bool get isConfigured => true;

  @override
  String get currentModel => 'fake-model';

  @override
  Stream<String> streamCoachReply({
    required String userMessage,
    required String systemPrompt,
    required List<Content> history,
    List<Tool>? tools,
    Future<Map<String, Object?>> Function(FunctionCall call)? onToolCall,
    String? imageBytesBase64,
    String? imageMimeType,
  }) async* {
    lastHistory = history;
    lastImageBytesBase64 = imageBytesBase64;
    lastImageMimeType = imageMimeType;
    if (invokeTool && onToolCall != null) {
      await onToolCall(FunctionCall('get_muscle_recovery', {}));
      toolCallsMade++;
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
    String? imageBytesBase64,
    String? imageMimeType,
  }) =>
      streamCoachReply(
        userMessage: userMessage,
        systemPrompt: systemPrompt,
        history: history,
        tools: tools,
        onToolCall: onToolCall,
        imageBytesBase64: imageBytesBase64,
        imageMimeType: imageMimeType,
      );

  @override
  Future<T> generateStructuredJson<T>({
    required String systemPrompt,
    required String userPrompt,
    required T Function(Map<String, dynamic> json) fromJson,
  }) =>
      throw UnimplementedError();
}

void main() {
  group('AiCoachViewModel', () {
    late MockStorageService storage;
    late WorkoutProvider provider;
    late ConversationManager conversations;
    late SettingsProvider settings;
    late PRManager pr;

    Future<AiCoachViewModel> buildVm(IAiService ai) async {
      provider = WorkoutProvider(
        storage,
        programManager: ProgramManager(storage),
      );
      await provider.init();
      pr = PRManager(storage);
      settings = SettingsProvider(storage);
      conversations = ConversationManager(storage);
      return AiCoachViewModel(
        ai: ai,
        coachTools: CoachToolService(workoutProvider: provider, prManager: pr),
        conversations: conversations,
        settings: settings,
      );
    }

    setUp(() {
      storage = MockStorageService();
    });

    test('sendMessage appends user + model messages and persists', () async {
      final vm = await buildVm(_FakeAiService());

      await vm.sendMessage('How am I doing?');

      expect(vm.messages, hasLength(2));
      expect(vm.messages[0].role, 'user');
      expect(vm.messages[0].text, 'How am I doing?');
      expect(vm.messages[1].role, 'model');
      expect(vm.messages[1].text, 'Hello world');
      expect(vm.isLoading, isFalse);
      expect(vm.streamingText, isEmpty);

      // Persisted.
      final stored = await storage.getAllConversations();
      expect(stored, hasLength(1));
      expect(stored.first.messages, hasLength(2));
    });

    test('blank or whitespace messages are ignored', () async {
      final vm = await buildVm(_FakeAiService());
      await vm.sendMessage('   ');
      expect(vm.messages, isEmpty);
    });

    test('runs the tool-call loop via CoachToolService', () async {
      final ai = _FakeAiService(invokeTool: true, chunks: const ['done']);
      final vm = await buildVm(ai);

      await vm.sendMessage('what can I train?');

      expect(ai.toolCallsMade, 1);
      expect(vm.messages.last.text, 'done');
    });

    test('newConversation then selectConversation swaps active state',
        () async {
      final vm = await buildVm(_FakeAiService());

      await vm.sendMessage('first chat');
      final firstId = vm.activeConversationId;
      expect(firstId, isNotNull);

      vm.newConversation();
      expect(vm.messages, isEmpty);

      await vm.sendMessage('second chat');
      final secondId = vm.activeConversationId;
      expect(secondId, isNot(firstId));
      expect(vm.conversations, hasLength(2));

      vm.selectConversation(firstId!);
      expect(vm.activeConversationId, firstId);
      expect(vm.messages.first.text, 'first chat');
    });

    test('pending image state can be set and cleared', () async {
      final vm = await buildVm(_FakeAiService());
      expect(vm.hasPendingImage, isFalse);
      expect(vm.pendingImageBytes, isNull);

      final testBytes = Uint8List.fromList([1, 2, 3, 4]);
      vm.setPendingImageForTesting(testBytes, 'image/jpeg');

      expect(vm.hasPendingImage, isTrue);
      expect(vm.pendingImageBytes, testBytes);

      vm.clearPendingImage();
      expect(vm.hasPendingImage, isFalse);
      expect(vm.pendingImageBytes, isNull);
    });

    test('sendMessage attaches pending image, passes to IAiService, and clears pending', () async {
      final ai = _FakeAiService();
      final vm = await buildVm(ai);

      final testBytes = Uint8List.fromList([10, 20, 30, 40]);
      vm.setPendingImageForTesting(testBytes, 'image/png');

      await vm.sendMessage('Check my form');

      expect(ai.lastImageBytesBase64, base64Encode(testBytes));
      expect(ai.lastImageMimeType, 'image/png');
      expect(vm.hasPendingImage, isFalse);
      expect(vm.pendingImageBytes, isNull);

      final userMsg = vm.messages.firstWhere((m) => m.role == 'user');
      expect(userMsg.imageBytesBase64, base64Encode(testBytes));
      expect(userMsg.imageMimeType, 'image/png');
    });

    test('sendMessage with image only (no text) is accepted and sends image', () async {
      final ai = _FakeAiService();
      final vm = await buildVm(ai);

      final testBytes = Uint8List.fromList([5, 6, 7, 8]);
      vm.setPendingImageForTesting(testBytes, 'image/jpeg');

      // Empty text is allowed when there is a pending image
      await vm.sendMessage('');

      expect(ai.lastImageBytesBase64, base64Encode(testBytes));
      expect(vm.messages, hasLength(2)); // user + model
      expect(vm.messages[0].imageBytesBase64, base64Encode(testBytes));
      expect(vm.hasPendingImage, isFalse);
    });

    test('sendMessage stores error message when IAiService throws', () async {
      final throwingVm = await buildVm(_ThrowingAiService());

      await throwingVm.sendMessage('cause error');

      expect(throwingVm.messages, hasLength(2));
      final errMsg = throwingVm.messages.last;
      expect(errMsg.role, 'model');
      expect(errMsg.text, contains('Error'));
      expect(throwingVm.isLoading, isFalse);
    });

    test('_buildHistory preserves attached images with DataPart and [Attached image] placeholder', () async {
      final ai = _FakeAiService();
      final vm = await buildVm(ai);

      // Send a message with image — this gets stored and becomes part of history
      // in the next turn.
      final imgBytes = Uint8List.fromList([1, 2, 3]);
      vm.setPendingImageForTesting(imgBytes, 'image/jpeg');
      await vm.sendMessage(''); // image-only first message

      // Second message triggers _buildHistory which must preserve the image bytes
      // as a DataPart while retaining the text fallback.
      await vm.sendMessage('follow up');

      expect(vm.messages.length, greaterThanOrEqualTo(4));
      expect(ai.lastHistory, isNotNull);
      expect(ai.lastHistory, isNotEmpty);
      final historyContent = ai.lastHistory!.first;
      final historyParts = historyContent.parts.toList();
      expect(historyParts.any((p) => p is DataPart), isTrue);
      final dataPart = historyParts.firstWhere((p) => p is DataPart) as DataPart;
      expect(dataPart.mimeType, 'image/jpeg');
      expect(dataPart.bytes, equals(imgBytes));
      expect(historyParts.any((p) => p is TextPart && p.text == '[Attached image]'), isTrue);

      // Verify Content.toJson() serializes the DataPart and TextPart
      final json = historyContent.toJson();
      expect(json['role'], 'user');
      final serializedParts = json['parts'] as List;
      expect(serializedParts, hasLength(2));
      expect(serializedParts[0], {
        'inlineData': {
          'mimeType': 'image/jpeg',
          'data': base64Encode(imgBytes),
        },
      });
      expect(serializedParts[1], {'text': '[Attached image]'});
    });

    test('deleteConversation removes it from the list', () async {
      final vm = await buildVm(_FakeAiService());

      await vm.sendMessage('to delete');
      final id = vm.activeConversationId!;
      expect(vm.conversations, hasLength(1));

      await vm.deleteConversation(id);
      expect(vm.conversations, isEmpty);
    });
  });
}

/// IAiService that always throws on streamCoachReply.
class _ThrowingAiService implements IAiService {
  @override
  bool get isConfigured => true;

  @override
  String get currentModel => 'throwing-model';

  @override
  Stream<String> streamCoachReply({
    required String userMessage,
    required String systemPrompt,
    required List<Content> history,
    List<Tool>? tools,
    Future<Map<String, Object?>> Function(FunctionCall call)? onToolCall,
    String? imageBytesBase64,
    String? imageMimeType,
  }) async* {
    throw Exception('simulated AI error');
  }

  @override
  Stream<String> streamChatReply({
    required String userMessage,
    required String systemPrompt,
    required List<Content> history,
    List<Tool>? tools,
    Future<Map<String, Object?>> Function(FunctionCall call)? onToolCall,
    String? imageBytesBase64,
    String? imageMimeType,
  }) => streamCoachReply(
        userMessage: userMessage,
        systemPrompt: systemPrompt,
        history: history,
        tools: tools,
        onToolCall: onToolCall,
        imageBytesBase64: imageBytesBase64,
        imageMimeType: imageMimeType,
      );

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
  Future<T> generateStructuredJson<T>({
    required String systemPrompt,
    required String userPrompt,
    required T Function(Map<String, dynamic> json) fromJson,
  }) => throw UnimplementedError();
}
