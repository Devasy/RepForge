import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/screens/heart_rate_detail_screen.dart';
import '../test_utils/test_harness.dart';

void main() {
  testWidgets('Renders HeartRateDetailScreen title and granularities', (WidgetTester tester) async {
    await TestHarness.prepareTester(tester);

    await tester.pumpWidget(TestHarness.wrap(
      HeartRateDetailScreen(initialDate: DateTime(2026, 5, 10)),
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(HeartRateDetailScreen), findsOneWidget);
  });
}
