import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/screens/widgets/langfuse_settings.dart';
import 'package:repforge/services/ai/observability/langfuse_service.dart';

void main() {
  testWidgets(
    'developer settings accept three fields and keep content capture opt-in',
    (tester) async {
      String? stored;
      final service = LangfuseService(write: (value) async => stored = value);
      addTearDown(service.dispose);
      tester.view.physicalSize = const Size(360, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(body: LangfuseSettingsDialog(service: service)),
        ),
      );
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(3));
      expect(tester.widget<TextField>(fields.at(2)).obscureText, isTrue);
      await tester.enterText(fields.at(0), 'https://cloud.langfuse.com');
      await tester.enterText(fields.at(1), 'pk-lf-test-public');
      await tester.enterText(fields.at(2), 'sk-lf-test-secret');
      final toggle = find.text('Enable Langfuse tracing');
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(jsonDecode(stored!)['enabled'], isTrue);
      expect(jsonDecode(stored!)['captureContent'], isFalse);
    },
  );
}
