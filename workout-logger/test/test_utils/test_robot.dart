// test_robot.dart — Fluent Page Object test automation robot for RepForge widget tests

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/managers/history_manager.dart';
import 'mock_storage_service.dart';
import 'test_harness.dart';

/// High-level expressive testing robot wrapping [WidgetTester].
class TestRobot {
  final WidgetTester tester;

  TestRobot(this.tester);

  /// Prepares viewport size and initializes screen widget under test.
  Future<void> pumpScreen(
    Widget widget, {
    MockStorageService? storage,
    WorkoutProvider? workoutProvider,
    SettingsProvider? settingsProvider,
    HistoryManager? historyManager,
  }) async {
    await TestHarness.prepareTester(tester);
    await tester.pumpWidget(TestHarness.wrap(
      widget,
      storage: storage,
      workoutProvider: workoutProvider,
      settingsProvider: settingsProvider,
      historyManager: historyManager,
    ));
    await tester.pumpAndSettle();
    tester.takeException();
  }

  /// Taps on a target matching text, icon, key, or Finder.
  Future<void> tap(dynamic target) async {
    final finder = _resolveFinder(target);
    expect(finder, findsOneWidget);
    await tester.tap(finder);
    await tester.pumpAndSettle();
    tester.takeException();
  }

  /// Enters text into an input field matching a label, hint, or Finder.
  Future<void> fill(dynamic target, String text) async {
    final finder = _resolveFinder(target);
    expect(finder, findsOneWidget);
    await tester.enterText(finder, text);
    await tester.pump();
    tester.takeException();
  }

  /// Triggers a back navigation event on active Navigator.
  Future<void> handlePop() async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    tester.takeException();
  }

  /// Asserts that a target matching text, type, or Finder is visible.
  void expectVisible(dynamic target, {int count = 1}) {
    final finder = _resolveFinder(target);
    if (count == 1) {
      expect(finder, findsOneWidget);
    } else {
      expect(finder, findsNWidgets(count));
    }
  }

  /// Asserts that a target matching text, type, or Finder is NOT visible.
  void expectNotVisible(dynamic target) {
    final finder = _resolveFinder(target);
    expect(finder, findsNothing);
  }

  Finder _resolveFinder(dynamic target) {
    if (target is Finder) return target;
    if (target is String) {
      final textFinder = find.text(target);
      if (textFinder.evaluate().isNotEmpty) return textFinder;
      return find.widgetWithText(TextField, target);
    }
    if (target is IconData) return find.byIcon(target);
    if (target is Key) return find.byKey(target);
    if (target is Type) return find.byType(target);
    throw ArgumentError('Cannot resolve finder for target: $target');
  }
}
