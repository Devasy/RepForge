import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/screens/widgets/time_exercise_card.dart';
import 'package:repforge/services/settings_provider.dart';

import '../../test_utils/mock_storage_service.dart';
import '../../test_utils/test_harness.dart';

void main() {
  late MockStorageService storage;
  late SettingsProvider settings;

  setUp(() {
    storage = MockStorageService();
    settings = SettingsProvider(storage);
  });

  Widget buildCard({
    required int durationSeconds,
    required ValueChanged<int> onDurationChanged,
    required double currentWeight,
    required ValueChanged<double> onWeightChanged,
    double initialWeight = 0.0,
  }) {
    return TestHarness.wrap(
      Scaffold(
        body: SingleChildScrollView(
          child: TimeExerciseCard(
            durationSeconds: durationSeconds,
            onDurationChanged: onDurationChanged,
            currentWeight: currentWeight,
            onWeightChanged: onWeightChanged,
            settings: settings,
            initialWeight: initialWeight,
          ),
        ),
      ),
      storage: storage,
      settingsProvider: settings,
    );
  }

  group('TimeExerciseCard Widget Tests', () {
    testWidgets('Renders initial state with hold time, weight, and mode chips', (tester) async {
      int changedDuration = -1;
      double changedWeight = -1.0;

      await tester.pumpWidget(
        buildCard(
          durationSeconds: 45,
          onDurationChanged: (d) => changedDuration = d,
          currentWeight: 10.0,
          onWeightChanged: (w) => changedWeight = w,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Stopwatch'), findsOneWidget);
      expect(find.text('Countdown'), findsOneWidget);
      expect(find.text('HOLD TIME'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('45s'), findsOneWidget);

      // Enter weight
      await tester.enterText(find.byType(TextField).first, '15.5');
      await tester.pump();
      expect(changedWeight, 15.5);
    });

    testWidgets('Stopwatch start, tick, pause, resume, and reset flow', (tester) async {
      int recordedDuration = -1;

      await tester.pumpWidget(
        buildCard(
          durationSeconds: 30,
          onDurationChanged: (d) => recordedDuration = d,
          currentWeight: 0,
          onWeightChanged: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      // Tap Start
      final playBtn = find.byIcon(Icons.play_arrow_rounded);
      expect(playBtn, findsOneWidget);
      await tester.tap(playBtn);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('HOLDING...'), findsOneWidget);

      // Advance time by 2 seconds
      await tester.pump(const Duration(seconds: 2));

      // Tap Pause
      final pauseBtn = find.byIcon(Icons.pause_rounded);
      expect(pauseBtn, findsOneWidget);
      await tester.tap(pauseBtn);
      await tester.pumpAndSettle();

      expect(recordedDuration, greaterThanOrEqualTo(0));
      expect(find.text('HOLD TIME'), findsOneWidget);

      // Tap Reset
      final resetBtn = find.byIcon(Icons.replay_rounded);
      expect(resetBtn, findsOneWidget);
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      expect(recordedDuration, 0);
      expect(find.text('00:00'), findsOneWidget);
    });

    testWidgets('Countdown mode toggle, tick, pause, adjustments (+5s/-5s), and reset', (tester) async {
      int recordedDuration = -1;

      await tester.pumpWidget(
        buildCard(
          durationSeconds: 60,
          onDurationChanged: (d) => recordedDuration = d,
          currentWeight: 0,
          onWeightChanged: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Countdown
      await tester.tap(find.text('Countdown'));
      await tester.pumpAndSettle();

      expect(find.text('TARGET TIME'), findsOneWidget);
      expect(find.text('01:00'), findsOneWidget);

      // Add 5 seconds (+5s)
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      expect(recordedDuration, 65);
      expect(find.text('01:05'), findsOneWidget);

      // Subtract 5 seconds (-5s)
      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pumpAndSettle();
      expect(recordedDuration, 60);
      expect(find.text('01:00'), findsOneWidget);

      // Start Countdown
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('COUNTING DOWN'), findsOneWidget);

      // Advance time
      await tester.pump(const Duration(seconds: 1));

      // Pause Countdown
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pumpAndSettle();
      expect(recordedDuration, greaterThanOrEqualTo(0));

      // Reset Countdown
      await tester.tap(find.byIcon(Icons.replay_rounded));
      await tester.pumpAndSettle();
      expect(find.text('01:00'), findsOneWidget);
    });

    testWidgets('Preset chips update target duration', (tester) async {
      int recordedDuration = -1;

      await tester.pumpWidget(
        buildCard(
          durationSeconds: 30,
          onDurationChanged: (d) => recordedDuration = d,
          currentWeight: 0,
          onWeightChanged: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      // Tap preset 90s
      await tester.tap(find.text('90s'));
      await tester.pumpAndSettle();
      expect(recordedDuration, 90);

      // Switch to countdown and tap 120s
      await tester.tap(find.text('Countdown'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('120s'));
      await tester.pumpAndSettle();
      expect(recordedDuration, 120);
      expect(find.text('02:00'), findsOneWidget);
    });

    testWidgets('Manual edit duration dialog set and cancel', (tester) async {
      int recordedDuration = -1;

      await tester.pumpWidget(
        buildCard(
          durationSeconds: 45,
          onDurationChanged: (d) => recordedDuration = d,
          currentWeight: 0,
          onWeightChanged: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      // Open manual edit dialog
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Set Duration (seconds)'), findsOneWidget);

      // Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Set Duration (seconds)'), findsNothing);

      // Open again and set
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      final dialogInput = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(dialogInput, '75');
      await tester.tap(find.text('Set'));
      await tester.pumpAndSettle();

      expect(recordedDuration, 75);
    });

    testWidgets('didUpdateWidget synchronizes duration and weight when idle', (tester) async {
      await tester.pumpWidget(
        buildCard(
          durationSeconds: 30,
          onDurationChanged: (_) {},
          currentWeight: 5.0,
          onWeightChanged: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('5'), findsOneWidget);

      // Re-pump with updated props
      await tester.pumpWidget(
        buildCard(
          durationSeconds: 90,
          onDurationChanged: (_) {},
          currentWeight: 12.0,
          onWeightChanged: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('12'), findsOneWidget);
      // Switch to timer to see 01:30
      await tester.tap(find.text('Countdown'));
      await tester.pumpAndSettle();
      expect(find.text('01:30'), findsOneWidget);
    });
  });
}
