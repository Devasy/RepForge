import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:repforge/screens/widgets/profile_sections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/ai/gemini_ai_service.dart';
import 'package:repforge/services/ai/ai_failure.dart';
import 'test_utils/mock_storage_service.dart';

void main() {
  testWidgets('AI settings switch disables fallback and restores saved model', (
    tester,
  ) async {
    final storage = MockStorageService();
    final settings = SettingsProvider(storage);
    await settings.init();
    await settings.setAllowModelFallbacks(true);
    final ai = GeminiAiService()
      ..init(
        'fixture-key',
        model: settings.geminiModel,
        allowModelFallbacks: true,
      )
      ..updateModel('gemini-2.5-flash-lite');
    addTearDown(settings.dispose);
    addTearDown(ai.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<GeminiAiService>.value(value: ai),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: AiSettingsSection()),
          ),
        ),
      ),
    );
    final toggle = find.widgetWithText(
      SwitchListTile,
      'Allow automatic model fallback',
    );
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(settings.allowModelFallbacks, isFalse);
    expect(ai.allowModelFallbacks, isFalse);
    expect(ai.currentModel, settings.geminiModel);
    expect(await storage.getSetting('allowModelFallbacks'), 'false');
  });
  test('failed preference write keeps the previous value', () async {
    final storage = MockStorageService();
    final settings = SettingsProvider(storage);
    await settings.setAllowModelFallbacks(true);
    storage.saveSettingErrorResolver = (key, value) =>
        key == 'allowModelFallbacks' ? StateError('Storage unavailable') : null;
    await expectLater(settings.setAllowModelFallbacks(false), throwsStateError);
    expect(settings.allowModelFallbacks, isTrue);
  });

  test('fallback preference is opt-in and survives reload', () async {
    final storage = MockStorageService();
    final settings = SettingsProvider(storage);
    await settings.init();
    expect(settings.allowModelFallbacks, isFalse);
    await settings.setAllowModelFallbacks(true);
    final restored = SettingsProvider(storage);
    await restored.init();
    expect(restored.allowModelFallbacks, isTrue);
    await restored.setAllowModelFallbacks(false);
    final off = SettingsProvider(storage);
    await off.init();
    expect(off.allowModelFallbacks, isFalse);
  });
  for (final backend in GeminiBackend.values) {
    for (final enabled in [false, true]) {
      test(
        '${backend.name}: automatic model switches require opt-in ($enabled)',
        () async {
          final models = <String>[];
          final ai =
              GeminiAiService(
                modelClientFactory: () => MockClient((r) async {
                  final model = r.url.path.split('/').last.split(':').first;
                  models.add(model);
                  if (model == 'gemini-3.8-flash') {
                    return http.Response('{}', 404);
                  }
                  final body = jsonEncode({
                    'candidates': [
                      {
                        'content': {
                          'role': 'model',
                          'parts': [
                            {'text': 'OK'},
                          ],
                        },
                        'finishReason': 'STOP',
                      },
                    ],
                  });
                  return http.Response(
                    backend == GeminiBackend.vertexExpress
                        ? body
                        : 'data: $body\n\n',
                    200,
                  );
                }),
              )..init(
                'fixture-key',
                backend: backend,
                model: 'gemini-3.8-flash',
                allowModelFallbacks: enabled,
              );
          addTearDown(ai.dispose);
          final reply = ai
              .streamCoachReply(
                userMessage: 'Hi',
                systemPrompt: 'Test',
                history: [],
              )
              .toList();
          if (enabled) {
            expect((await reply).join(), 'OK');
            expect(models, ['gemini-3.8-flash', 'gemini-3.7-flash']);
          } else {
            await expectLater(reply, throwsA(isA<AiFailure>()));
            expect(models, ['gemini-3.8-flash']);
            expect(ai.currentModel, 'gemini-3.8-flash');
          }
        },
      );
    }
  }
  test('disabling fallback overrides an earlier opt-in', () async {
    var count = 0;
    final ai =
        GeminiAiService(
            modelClientFactory: () => MockClient((_) async {
              count++;
              return http.Response('{}', 404);
            }),
          )
          ..init(
            'fixture-key',
            model: 'gemini-3.8-flash',
            allowModelFallbacks: true,
          )
          ..updateAllowModelFallbacks(false);
    addTearDown(ai.dispose);
    await expectLater(
      ai
          .streamCoachReply(
            userMessage: 'Hi',
            systemPrompt: 'Test',
            history: [],
          )
          .toList(),
      throwsA(isA<AiFailure>()),
    );
    expect(count, 1);
  });
}
