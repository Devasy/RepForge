// test_sweep.dart — Parametric loop helpers to sweep through UI states efficiently.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class TestSweep {
  /// Iterates over a list of texts or icons, tapping each item and triggering pumpAndSettle.
  static Future<void> tapAll(WidgetTester tester, List<dynamic> targets) async {
    for (final target in targets) {
      Finder finder;
      if (target is String) {
        finder = find.text(target);
      } else if (target is IconData) {
        finder = find.byIcon(target);
      } else if (target is Key) {
        finder = find.byKey(target);
      } else {
        continue;
      }

      if (finder.evaluate().isNotEmpty) {
        await tester.tap(finder.first);
        await tester.pumpAndSettle();
        tester.takeException();
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
