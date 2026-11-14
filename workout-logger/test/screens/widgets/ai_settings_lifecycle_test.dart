import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repforge/screens/widgets/profile_sections.dart';
import 'package:repforge/services/ai/gemini_ai_service.dart';
import 'package:repforge/services/settings_provider.dart';
import '../../test_utils/mock_storage_service.dart';

void main() {
  testWidgets('backend save can finish after settings has been disposed', (
    tester,
  ) async {
    final key = Completer<String?>();
    final settings = SettingsProvider(
      MockStorageService(),
      readVertexKey: () => key.future,
    );
    final gemini = GeminiAiService();
    addTearDown(settings.dispose);
    addTearDown(gemini.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<GeminiAiService>.value(value: gemini),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: AiSettingsSection()),
          ),
        ),
      ),
    );
    final picker = tester.widget<DropdownButtonFormField<GeminiBackend>>(
      find.byType(DropdownButtonFormField<GeminiBackend>),
    );
    picker.onChanged!(GeminiBackend.vertexExpress);
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    key.complete('vertex-key');
    await tester.pumpAndSettle();
    expect(settings.geminiBackend, GeminiBackend.vertexExpress);
    expect(gemini.backend, GeminiBackend.vertexExpress);
    expect(tester.takeException(), isNull);
  });
}
