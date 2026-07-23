import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repforge/screens/onboarding_screen.dart';
import 'package:repforge/services/settings_provider.dart';
import '../test_utils/mock_storage_service.dart';

Widget _wrapWithSettings({
  required SettingsProvider settingsProvider,
  required Widget child,
}) {
  return ChangeNotifierProvider<SettingsProvider>.value(
    value: settingsProvider,
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('Renders WelcomePage with title and name field', (WidgetTester tester) async {
    final storage = MockStorageService();
    final settings = SettingsProvider(storage);
    await settings.init();

    await tester.pumpWidget(_wrapWithSettings(
      settingsProvider: settings,
      child: WelcomePage(onComplete: () {}),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Welcome to'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Submitting user name calls setUserName and onComplete callback', (WidgetTester tester) async {
    final storage = MockStorageService();
    final settings = SettingsProvider(storage);
    await settings.init();

    bool completed = false;

    await tester.pumpWidget(_wrapWithSettings(
      settingsProvider: settings,
      child: WelcomePage(onComplete: () {
        completed = true;
      }),
    ));
    await tester.pumpAndSettle();

    // Enter name
    final nameField = find.byType(TextField);
    await tester.enterText(nameField, 'Alex');
    await tester.pump();

    // Tap Get Started button
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(settings.userName, equals('Alex'));
    expect(completed, isTrue);
  });
}
