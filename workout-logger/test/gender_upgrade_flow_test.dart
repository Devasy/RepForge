import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:repforge/main.dart';
import 'package:repforge/data/body_figure.dart';
import 'package:repforge/screens/home_screen.dart';
import 'package:repforge/screens/onboarding_screen.dart';
import 'package:repforge/services/settings_provider.dart';
import 'test_utils/mock_storage_service.dart';
import 'test_utils/test_harness.dart';

class _GenderFailingStorage extends MockStorageService {
  @override
  Future<void> saveSetting(String key, String value) async {
    if (key == 'userGender') throw StateError('Write failed');
    await super.saveSetting(key, value);
  }
}

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'RepForge',
      packageName: 'com.devasy.repforge',
      version: '2.1.7',
      buildNumber: '65',
      buildSignature: '',
    );
  });

  testWidgets('upgrader is asked before home or release notes', (tester) async {
    await TestHarness.prepareTester(tester);
    final storage = MockStorageService();
    await storage.saveSetting('userName', 'Existing lifter');
    await storage.saveSetting('lastSeenVersion', '2.1.6');
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(
      TestHarness.wrap(
        const AppInitializer(),
        storage: storage,
        settingsProvider: settings,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GenderSetupPage), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.textContaining('Updated to'), findsNothing);
    expect(await storage.getSetting('userGender'), isNull);
    expect(await storage.getSetting('lastSeenVersion'), '2.1.6');
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved selection unlocks home and is not requested on restart', (
    tester,
  ) async {
    await TestHarness.prepareTester(tester);
    final storage = MockStorageService();
    await storage.saveSetting('userName', 'Existing lifter');
    await storage.saveSetting('lastSeenVersion', '2.1.7');
    final settings = SettingsProvider(storage);
    await tester.pumpWidget(
      TestHarness.wrap(
        const AppInitializer(),
        storage: storage,
        settingsProvider: settings,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Female'));
    await tester.pumpAndSettle();
    expect(await storage.getSetting('userGender'), 'female');
    expect(settings.bodyFigure, BodyFigure.female);
    expect(find.byType(GenderSetupPage), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    final restored = SettingsProvider(storage);
    await tester.pumpWidget(
      TestHarness.wrap(
        const AppInitializer(key: ValueKey('restart')),
        storage: storage,
        settingsProvider: restored,
      ),
    );
    await tester.pumpAndSettle();
    expect(restored.userGender, UserGender.female);
    expect(restored.needsGenderSelection, isFalse);
    expect(find.byType(GenderSetupPage), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed save keeps setup visible and retry available', (
    tester,
  ) async {
    final settings = SettingsProvider(_GenderFailingStorage());
    bool complete = false;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          home: GenderSetupPage(onComplete: () => complete = true),
        ),
      ),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Female'));
    await tester.pumpAndSettle();
    expect(complete, isFalse);
    expect(settings.needsGenderSelection, isTrue);
    expect(
      find.text('Could not save your gender. Please try again.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Female'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('explicit prefer not to say is a saved choice', (tester) async {
    final storage = MockStorageService();
    final settings = SettingsProvider(storage);
    bool complete = false;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          home: GenderSetupPage(onComplete: () => complete = true),
        ),
      ),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Prefer not to say'));
    await tester.pumpAndSettle();
    expect(complete, isTrue);
    final restored = SettingsProvider(storage);
    await restored.init();
    expect(restored.needsGenderSelection, isFalse);
    expect(restored.userGender, UserGender.preferNotToSay);
  });
}
