import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:repforge/screens/onboarding_screen.dart';
import 'package:repforge/services/release_service.dart';
import 'package:repforge/services/changelog.dart';
import 'package:repforge/screens/widgets/release_widgets.dart';

void main() {
  const groupedNotes =
      '## [2.1.6]\n### Features added\n- New feature.\n### Fixes\n- New fix.\n## [2.1.5]\n### Removed\n- Old removal.';

  testWidgets(
    'releases and types collapse independently and unmount hidden notes',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReleaseNotesView(releases: parseChangelog(groupedNotes)),
            ),
          ),
        ),
      );
      expect(find.text('v2.1.6'), findsOneWidget);
      expect(find.text('v2.1.5'), findsOneWidget);
      expect(find.text('2 changes'), findsOneWidget);
      expect(find.text('Features added'), findsOneWidget);
      expect(find.text('Removed'), findsNothing);
      expect(find.text('• New feature.'), findsNothing);
      await tester.tap(find.text('Features added'));
      await tester.pumpAndSettle();
      expect(find.text('• New feature.'), findsOneWidget);
      expect(find.text('• New fix.'), findsNothing);
      await tester.tap(find.text('Fixes'));
      await tester.pumpAndSettle();
      expect(find.text('• New fix.'), findsOneWidget);
      await tester.tap(find.text('Features added'));
      await tester.pumpAndSettle();
      expect(find.text('• New feature.'), findsNothing);
      expect(find.text('• New fix.'), findsOneWidget);
      await tester.tap(find.text('v2.1.6'));
      await tester.pumpAndSettle();
      expect(find.text('• New fix.'), findsNothing);
      await tester.tap(find.text('v2.1.5'));
      await tester.pumpAndSettle();
      expect(find.text('Removed'), findsOneWidget);
      await tester.tap(find.text('Removed'));
      await tester.pumpAndSettle();
      expect(find.text('• Old removal.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'large notes remain scrollable at large text scale on a narrow screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 440));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final notes =
          '## [2.1.6]\n### Known limitations\n${List.generate(120, (i) => '- Long user-facing limitation $i with enough detail to wrap over several lines.').join('\n')}';
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReleaseNotesView(releases: parseChangelog(notes)),
            ),
          ),
        ),
      );
      expect(find.byType(SelectableText), findsNothing);
      await tester.tap(find.text('Known limitations'));
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsNWidgets(120));
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -700),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('update notice shares the changelog renderer and uses raw notes', (
    tester,
  ) async {
    final client = MockClient(
      (request) async => http.Response(
        request.url.host == 'raw.githubusercontent.com'
            ? groupedNotes
            : '[{"tag_name":"v2.1.6","body":"API fallback prose","html_url":"https://github.com/Devasy/RepForge/releases/tag/v2.1.6"}]',
        200,
      ),
    );
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UpdateNotice(
            current: '2.1.5',
            service: ReleaseService(client: client),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update available: v2.1.6'));
    await tester.pumpAndSettle();
    expect(find.byType(ReleaseNotesView), findsOneWidget);
    expect(find.text('Features added'), findsOneWidget);
    expect(find.text('API fallback prose'), findsNothing);
    expect(find.text('v2.1.5'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Fixes'));
    await tester.pumpAndSettle();
    expect(find.text('• New fix.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
