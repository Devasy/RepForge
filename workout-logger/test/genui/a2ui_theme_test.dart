import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/genui/src/a2ui_panels.dart';
import 'package:repforge/genui/src/a2ui_theme.dart';

/// A theme deliberately distinct from [A2UiTheme.dark] in every field the
/// injection tests check, so those tests can only pass if
/// [A2UiThemeProvider.of] genuinely performed the InheritedWidget lookup
/// rather than falling through to the default.
const _injectedTestTheme = A2UiTheme(
  surface: Color(0xFF000001),
  border: Color(0xFF000002),
  divider: Color(0xFF000003),
  textPrimary: Color(0xFF000004),
  textSoft: Color(0xFF000005),
  textMuted: Color(0xFF000006),
  textFaint: Color(0xFF000007),
  accent: Color(0xFF00FF00),
  positive: Color(0xFF000008),
  negative: Color(0xFF000009),
  seriesPalette: [Color(0xFF00000A)],
  spacing: 99,
  radius: 98,
  pillRadius: 97,
);

void main() {
  group('A2UiThemeProvider', () {
    testWidgets('falls back to A2UiTheme.dark when no provider is present',
        (tester) async {
      late A2UiTheme resolved;
      await tester.pumpWidget(
        Builder(builder: (context) {
          resolved = A2UiThemeProvider.of(context);
          return const SizedBox.shrink();
        }),
      );
      expect(resolved.accent, A2UiTheme.dark.accent);
    });

    testWidgets(
        'supplies the injected theme to descendants and falls back for '
        'non-descendants', (tester) async {
      late A2UiTheme resolvedInside;
      late A2UiTheme resolvedOutside;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              A2UiThemeProvider(
                theme: _injectedTestTheme,
                child: Builder(builder: (context) {
                  resolvedInside = A2UiThemeProvider.of(context);
                  return const SizedBox.shrink();
                }),
              ),
              // Sibling of the provider, not a descendant of it: must still
              // fall back to A2UiTheme.dark.
              Builder(builder: (context) {
                resolvedOutside = A2UiThemeProvider.of(context);
                return const SizedBox.shrink();
              }),
            ],
          ),
        ),
      );

      expect(resolvedInside.accent, _injectedTestTheme.accent);
      expect(resolvedInside.surface, _injectedTestTheme.surface);
      expect(resolvedInside.spacing, _injectedTestTheme.spacing);

      expect(resolvedOutside.accent, A2UiTheme.dark.accent);
      expect(resolvedOutside.surface, A2UiTheme.dark.surface);
    });
  });

  group('A2UiTheme', () {
    test('seriesColor cycles through the palette', () {
      const t = A2UiTheme.dark;
      expect(t.seriesColor(0), t.seriesPalette[0]);
      expect(t.seriesColor(5), t.seriesPalette[0]);
      expect(t.seriesColor(6), t.seriesPalette[1]);
    });
  });

  group('shared chrome', () {
    testWidgets('A2UiEmptyPanel shows its message', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: A2UiEmptyPanel(message: 'No chart data', theme: A2UiTheme.dark),
        ),
      ));
      expect(find.text('No chart data'), findsOneWidget);
    });

    testWidgets('A2UiPanelTitle renders title and trailing text',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: A2UiPanelTitle(
            title: 'Volume',
            trailing: 'r = +0.82',
            theme: A2UiTheme.dark,
          ),
        ),
      ));
      expect(find.text('Volume'), findsOneWidget);
      expect(find.text('r = +0.82'), findsOneWidget);
    });

    testWidgets('A2UiLegend renders one entry per name', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: A2UiLegend(names: ['Biceps', 'Triceps'], theme: A2UiTheme.dark),
        ),
      ));
      expect(find.text('Biceps'), findsOneWidget);
      expect(find.text('Triceps'), findsOneWidget);
    });
  });

  group('A2UiPanel', () {
    testWidgets(
        'pads with theme.spacing, decorates with theme colors, and renders '
        'its child by default', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: A2UiPanel(
            theme: A2UiTheme.dark,
            child: Text('probe'),
          ),
        ),
      ));

      expect(find.text('probe'), findsOneWidget);

      final container = tester.widget<Container>(find.descendant(
        of: find.byType(A2UiPanel),
        matching: find.byType(Container),
      ));
      expect(container.padding, EdgeInsets.all(A2UiTheme.dark.spacing));

      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, A2UiTheme.dark.surface);
      expect(decoration.border, Border.all(color: A2UiTheme.dark.border));
    });

    testWidgets('uses zero padding when padded is false', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: A2UiPanel(
            theme: A2UiTheme.dark,
            padded: false,
            child: Text('probe'),
          ),
        ),
      ));

      expect(find.text('probe'), findsOneWidget);

      final container = tester.widget<Container>(find.descendant(
        of: find.byType(A2UiPanel),
        matching: find.byType(Container),
      ));
      expect(container.padding, EdgeInsets.zero);
    });
  });
}
