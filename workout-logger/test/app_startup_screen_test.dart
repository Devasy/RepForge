import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:repforge/main.dart';
import 'package:repforge/screens/app_startup_screen.dart';
import 'package:repforge/screens/onboarding_screen.dart';
import 'package:repforge/theme/app_theme.dart';

import 'test_utils/mock_storage_service.dart';
import 'test_utils/test_harness.dart';

class _DelayedStartupStorage extends MockStorageService {
  final ready = Completer<void>();
  bool failFirst = false;
  int attempts = 0;

  @override
  Future<void> init() async {
    attempts++;
    if (failFirst && attempts == 1) throw StateError('Storage unavailable');
    await ready.future;
  }
}

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'RepForge',
      packageName: 'com.devasy.repforge',
      version: '2.2.2',
      buildNumber: '71',
      buildSignature: '',
    );
  });

  testWidgets('icon loading stays until initialization finishes', (
    tester,
  ) async {
    final storage = _DelayedStartupStorage();
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      TestHarness.wrap(const AppInitializer(), storage: storage),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(AppLoadingScreen), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    await tester.runAsync(() async {
      await precacheImage(
        tester.widget<Image>(find.byType(Image)).image,
        tester.element(find.byType(AppLoadingScreen)),
      );
    });
    await tester.pump();
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
    expect(find.bySemanticsLabel('Starting RepForge'), findsOneWidget);
    semantics.dispose();
    expect(find.byType(Text), findsNothing);
    expect(find.byType(WelcomePage), findsNothing);

    storage.ready.complete();
    await tester.pumpAndSettle();
    expect(find.byType(AppLoadingScreen), findsNothing);
    expect(find.byType(WelcomePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('startup failure offers retry and returns to loading', (
    tester,
  ) async {
    final storage = _DelayedStartupStorage()..failFirst = true;
    await tester.pumpWidget(
      TestHarness.wrap(const AppInitializer(), storage: storage),
    );
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t start RepForge'), findsOneWidget);
    expect(find.text('Storage unavailable'), findsNothing);
    await tester.tap(find.text('Error details'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Storage unavailable'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(storage.attempts, 2);
    expect(find.byType(AppLoadingScreen), findsOneWidget);
    storage.ready.complete();
    await tester.pumpAndSettle();
    expect(find.byType(WelcomePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion keeps the icon and startup announcement', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: AppLoadingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.bySemanticsLabel('Starting RepForge'), findsOneWidget);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('long error details remain usable on a small large-text screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: AppStartupErrorScreen(
            error: List.filled(50, 'Storage could not be opened.').join('\n'),
            onRetry: () => retried = true,
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Error details'));
    await tester.tap(find.text('Error details'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Retry'));
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
    expect(tester.takeException(), isNull);
  });
}
