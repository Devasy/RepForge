import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:repforge/screens/onboarding_screen.dart';
import 'package:repforge/services/release_service.dart';

void main() {
  testWidgets(
    'upgrade sheet includes skipped versions and scrolls on a small screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 440));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final client = MockClient(
        (_) async => http.Response(
          [
            for (final version in ['2.1.8', '2.1.7', '2.1.6', '2.1.5'])
              '## [$version]\n### Features added\n${List.filled(20, '- Features, fixes and limitations for $version.').join('\n')}',
          ].join('\n'),
          200,
        ),
      );
      addTearDown(client.close);
      final service = ReleaseService(client: client);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showVersionUpdateSheet(
                  context,
                  '2.1.7',
                  previousVersion: '2.1.5',
                  releaseService: service,
                ),
                child: const Text('Upgrade'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Upgrade'));
      await tester.pumpAndSettle();
      expect(find.text('v2.1.7'), findsOneWidget);
      expect(find.text('v2.1.6'), findsOneWidget);
      expect(find.text('v2.1.8'), findsNothing);
      expect(find.text('v2.1.5'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -800),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
