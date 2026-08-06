import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/genui/src/a2ui_panels.dart';
import 'package:repforge/genui/src/a2ui_theme.dart';
import 'package:repforge/theme/a2ui_app_theme.dart';
import 'package:repforge/theme/app_theme.dart';

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

    testWidgets('supplies the injected theme to descendants', (tester) async {
      late A2UiTheme resolved;
      await tester.pumpWidget(
        A2UiThemeProvider(
          theme: repforgeA2UiTheme,
          child: Builder(builder: (context) {
            resolved = A2UiThemeProvider.of(context);
            return const SizedBox.shrink();
          }),
        ),
      );
      expect(resolved.accent, AppColors.primary);
      expect(resolved.surface, AppColors.card);
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
}
