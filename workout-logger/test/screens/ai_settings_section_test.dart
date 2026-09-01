// Widget tests for the Gemini model dropdown + thinking-level slider in
// AiSettingsSection.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repforge/screens/widgets/profile_sections.dart';
import 'package:repforge/services/ai/gemini_ai_service.dart';
import 'package:repforge/services/settings_provider.dart';
import '../test_utils/mock_storage_service.dart';

Widget _wrap(SettingsProvider settings, GeminiAiService gemini) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsProvider>.value(value: settings),
      ChangeNotifierProvider<GeminiAiService>.value(value: gemini),
    ],
    child: const MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: AiSettingsSection())),
    ),
  );
}

void main() {
  late SettingsProvider settings;
  late GeminiAiService gemini;

  setUp(() async {
    settings = SettingsProvider(MockStorageService());
    await settings.init();
    gemini = GeminiAiService();
  });

  testWidgets('model picker is a dropdown showing the current model', (tester) async {
    await tester.pumpWidget(_wrap(settings, gemini));
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.text('Gemini 3.6 Flash'), findsOneWidget);
  });

  testWidgets('selecting gemini-3.7-flash from the dropdown clamps the thinking-level slider off minimal', (tester) async {
    await settings.setGeminiThinkingLevel('minimal');
    await tester.pumpWidget(_wrap(settings, gemini));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gemini 3.7 Flash').last);
    await tester.pumpAndSettle();

    expect(settings.geminiThinkingLevel, 'low');
  });

  testWidgets('thinking-level slider is hidden for gemini-2.5-flash', (tester) async {
    await settings.setGeminiModel('gemini-2.5-flash');
    await tester.pumpWidget(_wrap(settings, gemini));
    await tester.pumpAndSettle();

    expect(find.text('THINKING LEVEL'), findsNothing);
  });
}
