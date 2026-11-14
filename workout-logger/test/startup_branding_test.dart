import 'package:material_ui/material_ui.dart';
import 'dart:async';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:repforge/screens/onboarding_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/main.dart';
import 'package:repforge/screens/widgets/repforge_startup_screen.dart';
import 'package:repforge/theme/app_theme.dart';
import 'test_utils/mock_storage_service.dart';
import 'test_utils/test_harness.dart';

class _WaitingStorage extends MockStorageService {
  final ready = Completer<void>();
  int attempts = 0;
  @override
  Future<void> init() => attempts++ == 0 ? ready.future : Future.value();
}

void main() {
  testWidgets('branded startup fits narrow large text and landscape', (
    tester,
  ) async {
    for (final size in [const Size(320, 640), const Size(640, 320)]) {
      await TestHarness.prepareTester(tester, size: size);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: const TextScaler.linear(1.8),
            ),
            child: const RepForgeStartupScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('RepForge'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('loading and failed startup keep RepForge branding and retry', (
    tester,
  ) async {
    PackageInfo.setMockInitialValues(
      appName: 'RepForge',
      packageName: 'repforge',
      version: '2.2.2',
      buildNumber: '73',
      buildSignature: '',
    );
    final storage = _WaitingStorage();
    await tester.pumpWidget(
      TestHarness.wrap(const AppInitializer(), storage: storage),
    );
    await tester.pump();
    expect(find.text('RepForge'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Preparing your training'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Workout Logger'), findsNothing);
    storage.ready.completeError(StateError('Storage unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('Could not start RepForge'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Could not start RepForge'), findsNothing);
    expect(find.byType(WelcomePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
