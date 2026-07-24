// test_sweep.dart — Parametric loop helpers to sweep through UI states efficiently.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class TestSweep {
  /// Iterates over a list of texts or icons, tapping each item and triggering pumpAndSettle.
  static Future<void> tapAll(WidgetTester tester, List<dynamic> targets) async {
    for (final target in targets) {
      final Finder? finder = target is String
          ? find.text(target)
          : target is IconData
              ? find.byIcon(target)
              : target is Key
                  ? find.byKey(target)
                  : null;
      if (finder == null) continue;

      if (finder.evaluate().isNotEmpty) {
        await tester.tap(finder.first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    }
  }

  /// Populates a series of text fields with values and pumps frame.
  static Future<void> fillFields(WidgetTester tester, Map<Finder, String> fieldValues) async {
    for (final entry in fieldValues.entries) {
      if (entry.key.evaluate().isNotEmpty) {
        await tester.enterText(entry.key, entry.value);
        await tester.pump();
      }
    }
    await tester.pumpAndSettle();
  }
}
