import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/screens/widgets/rf_selection_group.dart';
import 'package:repforge/theme/app_theme.dart';

void main() {
  setUpAll(() async {
    final font = FontLoader('Geist')
      ..addFont(rootBundle.load('assets/fonts/Geist-Variable.ttf'));
    await font.load();
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets('compact health range remains one row at 320dp, scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: RFSelectionGroup<int>(
                  compact: true,
                  options: const [
                    RFSelectionOption(value: 0, label: 'Day'),
                    RFSelectionOption(value: 1, label: 'Week'),
                    RFSelectionOption(value: 2, label: 'Month'),
                    RFSelectionOption(value: 3, label: 'Year'),
                  ],
                  selected: 0,
                  onChanged: (_) => fail('Unexpected selection during layout'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final firstY = tester.getTopLeft(find.text('Day')).dy;
      if (scale == 1) {
        expect(tester.getTopLeft(find.text('Year')).dy, firstY);
        expect(
          tester.getSize(find.byType(RFSelectionGroup<int>)).height,
          lessThanOrEqualTo(60),
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('chart title and intrinsic range share a header at 320dp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              children: [
                const Text('Volume Trend'),
                RFSelectionGroup<int>(
                  compact: true,
                  expanded: false,
                  options: const [
                    RFSelectionOption(value: 0, label: '4W'),
                    RFSelectionOption(value: 1, label: '12W'),
                    RFSelectionOption(value: 2, label: 'All'),
                  ],
                  selected: 0,
                  onChanged: (_) => fail('Unexpected selection during layout'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(RFSelectionGroup<int>)).width,
      lessThan(180),
    );
    expect(
      tester.getTopLeft(find.byType(RFSelectionGroup<int>)).dy,
      tester.getTopLeft(find.text('Volume Trend')).dy,
    );
    expect(tester.takeException(), isNull);
  });
}
