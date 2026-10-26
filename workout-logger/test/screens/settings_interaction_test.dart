import 'package:repforge/screens/widgets/rf_form_fields.dart';
import 'package:repforge/screens/widgets/rf_selection_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repforge/screens/widgets/profile_sections.dart';
import 'package:repforge/services/ai/gemini_ai_service.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/theme/app_theme.dart';

import '../test_utils/mock_storage_service.dart';

Widget _wrap(
  SettingsProvider settings,
  GeminiAiService gemini,
  WidgetBuilder builder, {
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: settings),
      ChangeNotifierProvider.value(value: gemini),
    ],
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      home: Consumer<SettingsProvider>(
        builder: (context, _, _) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: Scaffold(body: SingleChildScrollView(child: builder(context))),
        ),
      ),
    ),
  );
}

void main() {
  late MockStorageService storage;
  late SettingsProvider settings;
  late GeminiAiService gemini;

  setUp(() async {
    storage = MockStorageService();
    settings = SettingsProvider(storage);
    await settings.init();
    gemini = GeminiAiService();
  });

  testWidgets('coach controls fit a small screen with doubled text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _wrap(
        settings,
        gemini,
        (_) => const Padding(
          padding: EdgeInsets.all(16),
          child: AiSettingsSection(),
        ),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Advanced coach settings'));
    await tester.tap(find.text('Advanced coach settings'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Save API Key'));
    expect(find.text('Save API Key').hitTestable(), findsOneWidget);
  });

  testWidgets(
    'advanced options stay out of basic setup and do not write on open',
    (tester) async {
      await tester.pumpWidget(
        _wrap(settings, gemini, (_) => const AiSettingsSection()),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Slider), findsNothing);
      expect(find.byType(RFDropdown<String>), findsOneWidget);
      expect(find.text('Save API Key'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Save API Key')).dy,
        lessThan(tester.getTopLeft(find.byType(RFDropdown<String>)).dy),
      );
      await tester.enterText(
        find.descendant(
          of: find.byType(RFTextField),
          matching: find.byType(TextField),
        ),
        'demo-key',
      );
      final writes = storage.saveSettingCallCount;
      await tester.ensureVisible(find.text('Advanced coach settings'));
      await tester.tap(find.text('Advanced coach settings'));
      await tester.pumpAndSettle();
      expect(find.byType(Slider), findsNWidgets(2));
      await tester.tap(find.text('Advanced coach settings'));
      await tester.pumpAndSettle();
      expect(find.byType(Slider), findsNothing);
      expect(storage.saveSettingCallCount, writes);
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byType(RFTextField),
                matching: find.byType(TextField),
              ),
            )
            .controller!
            .text,
        'demo-key',
      );
      expect(settings.geminiApiKey, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('expanded tool limit saves and remains after reopening', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(settings, gemini, (_) => const AiSettingsSection()),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Advanced coach settings'));
    await tester.tap(find.text('Advanced coach settings'));
    await tester.pumpAndSettle();
    final control = tester.widget<Slider>(find.byType(Slider).last);
    control.onChanged!(7);
    control.onChangeEnd!(7);
    await tester.pumpAndSettle();
    expect(settings.geminiMaxToolRounds, 7);
    final restored = SettingsProvider(storage);
    await restored.init();
    expect(restored.geminiMaxToolRounds, 7);
    await tester.ensureVisible(find.text('Advanced coach settings'));
    await tester.tap(find.text('Advanced coach settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Advanced coach settings'));
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(find.byType(Slider).last).value, 7);
    expect(tester.takeException(), isNull);
  });

  testWidgets('named key visibility button hides and reveals without saving', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(settings, gemini, (_) => const AiSettingsSection()),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(RFTextField),
        matching: find.byType(TextField),
      ),
      'demo-key',
    );
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byType(RFTextField),
              matching: find.byType(TextField),
            ),
          )
          .obscureText,
      isTrue,
    );
    await tester.tap(find.byTooltip('Show API key'));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byType(RFTextField),
              matching: find.byType(TextField),
            ),
          )
          .obscureText,
      isFalse,
    );
    await tester.tap(find.byTooltip('Hide API key'));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byType(RFTextField),
              matching: find.byType(TextField),
            ),
          )
          .obscureText,
      isTrue,
    );
    expect(settings.geminiApiKey, isEmpty);
  });

  testWidgets('estimated 1RM toggles by tapping its descriptive row', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        settings,
        gemini,
        (_) => PreferencesSection(settings: settings, onHaptic: () {}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Show estimated 1RM'));
    await tester.tap(find.text('Show estimated 1RM'));
    await tester.pumpAndSettle();
    expect(settings.showAdvancedMetrics, isTrue);
    expect(await storage.getSetting('showAdvancedMetrics'), 'true');
  });

  testWidgets('unit choice supports keyboard activation and persists', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        settings,
        gemini,
        (_) => PreferencesSection(settings: settings, onHaptic: () {}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('lbs'));
    Focus.of(tester.element(find.text('lbs'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(settings.weightUnit, WeightUnit.lbs);
    final restored = SettingsProvider(storage);
    await restored.init();
    expect(restored.weightUnit, WeightUnit.lbs);
    expect(
      tester
          .widget<RFSelectionGroup<WeightUnit>>(
            find.byType(RFSelectionGroup<WeightUnit>),
          )
          .selected,
      WeightUnit.lbs,
    );
  });

  testWidgets('increment choices have usable targets and persist selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        settings,
        gemini,
        (_) => PreferencesSection(settings: settings, onHaptic: () {}),
      ),
    );
    await tester.pumpAndSettle();
    final choice = find.widgetWithText(FilledButton, '5 kg');
    await tester.ensureVisible(choice);
    expect(tester.getSize(choice).height, greaterThanOrEqualTo(48));
    await tester.tap(choice);
    await tester.pumpAndSettle();
    expect(settings.weightIncrement, 5);
    expect(
      tester
          .widget<RFSelectionGroup<double>>(
            find.byType(RFSelectionGroup<double>),
          )
          .selected,
      5,
    );
    final restored = SettingsProvider(storage);
    await restored.init();
    expect(restored.weightIncrement, 5);
  });
}
