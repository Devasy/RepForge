import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repforge/screens/widgets/profile_sections.dart';
import 'package:repforge/services/settings_provider.dart';

import '../../test_utils/mock_storage_service.dart';

void main() {
  testWidgets('Sync now tile appears when readiness is enabled and invokes callback on tap',
      (tester) async {
    final settings = SettingsProvider(MockStorageService());
    await settings.init();
    await settings.setReadinessEnabled(true);

    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HealthConnectSection(
          settings: settings,
          isLoading: false,
          onToggle: (_) async {},
          isReadinessLoading: false,
          onReadinessToggle: (_) async {},
          isHealthSyncLoading: false,
          onHealthSyncNow: () => tapped = true,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Sync coach data now'), findsOneWidget);
    await tester.tap(find.text('Sync coach data now'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('Sync now tile is hidden when readiness is disabled', (tester) async {
    final settings = SettingsProvider(MockStorageService());
    await settings.init();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HealthConnectSection(
          settings: settings,
          isLoading: false,
          onToggle: (_) async {},
          isReadinessLoading: false,
          onReadinessToggle: (_) async {},
          isHealthSyncLoading: false,
          onHealthSyncNow: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Sync coach data now'), findsNothing);
  });
}
