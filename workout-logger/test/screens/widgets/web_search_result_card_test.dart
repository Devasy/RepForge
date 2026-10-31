import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/web_search_result.dart';
import 'package:repforge/screens/widgets/web_search_result_card.dart';
import 'package:repforge/theme/app_theme.dart';

void main() {
  testWidgets(
    'grounded replies show source links and original Google suggestions at large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const html = '<div>Original Google suggestions</div>';
      String? received;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 900),
                textScaler: TextScaler.linear(2),
              ),
              child: SingleChildScrollView(
                child: WebSearchResultCard(
                  result: const WebSearchResult(
                    query: 'Resistance training research',
                    text: 'Evidence summary',
                    sources: [
                      WebSearchSource(
                        title: 'A primary research source with a long title',
                        url: 'https://example.org/research',
                      ),
                    ],
                    suggestionsHtml: html,
                  ),
                  suggestionsBuilder: (value) {
                    received = value;
                    return const Text('Google Search suggestions');
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Evidence summary'), findsOneWidget);
      expect(
        find.text('A primary research source with a long title'),
        findsOneWidget,
      );
      expect(find.text('Google Search suggestions'), findsOneWidget);
      expect(received, html);
      expect(tester.takeException(), isNull);
    },
  );
}
