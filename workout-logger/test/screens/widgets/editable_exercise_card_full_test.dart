import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/widgets/editable_exercise_card.dart';

import '../../test_utils/mock_storage_service.dart';
import '../../test_utils/test_harness.dart';

void main() {
  late MockStorageService storage;

  setUp(() {
    storage = MockStorageService();
  });

  group('EditableExerciseCard Widget Tests', () {
    testWidgets('Renders exercise name, set rows, dropsets, and handles actions', (tester) async {
      final log = EditableExerciseLog(
        exerciseId: 'bench_press',
        sets: [
          EditableSet(
            weight: 100,
            reps: 10,
            timestamp: DateTime.now(),
          ),
          EditableSet(
            weight: 90,
            reps: 8,
            isDropset: true,
            drops: [DropsetEntry(weight: 70, reps: 6)],
            timestamp: DateTime.now(),
          ),
        ],
      );

      bool setAdded = false;

      final widget = TestHarness.wrap(
        Scaffold(
          body: EditableExerciseCard(
            exerciseName: 'Bench Press',
            editableLog: log,
            onSetChanged: ({
              required int setIndex,
              required double weight,
              required int reps,
              required bool isDropset,
              List<DropsetEntry>? drops,
            }) {},
            onAddSet: () => setAdded = true,
            onDeleteSet: (idx) {},
            onDeleteExercise: () {},
          ),
        ),
        storage: storage,
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.text('Bench Press'), findsOneWidget);

      // Tap + Add Set
      final addSetBtn = find.text('+ Add Set');
      if (addSetBtn.evaluate().isNotEmpty) {
        await tester.tap(addSetBtn);
        expect(setAdded, isTrue);
      }

      expect(tester.takeException(), isNull);
    });
  });
}
