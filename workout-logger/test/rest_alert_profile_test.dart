import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/screens/widgets/profile_sections.dart';
import 'package:repforge/services/settings_provider.dart';

import 'test_utils/mock_storage_service.dart';

void main() {
  testWidgets('rest alert controls save preferences and report failed saves', (
    tester,
  ) async {
    final storage = MockStorageService();
    final settings = SettingsProvider(storage);
    await settings.init();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PreferencesSection(settings: settings, onHaptic: () {}),
          ),
        ),
      ),
    );

    final sound = find.widgetWithText(SwitchListTile, 'Sound');
    await tester.ensureVisible(sound);
    await tester.tap(sound);
    await tester.pump();
    expect(settings.restAlertSound, isFalse);
    expect(storage.settings['restAlertSound'], 'false');

    storage.saveSettingErrorResolver = (key, _) =>
        key == 'restAlertVibration' ? StateError('disk full') : null;
    final vibration = find.widgetWithText(SwitchListTile, 'Vibration');
    await tester.ensureVisible(vibration);
    await tester.tap(vibration);
    await tester.pump();
    expect(settings.restAlertVibration, isTrue);
    expect(find.text('Could not save rest alert setting.'), findsOneWidget);
  });
}
