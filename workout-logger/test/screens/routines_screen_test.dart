import 'package:repforge/services/managers/program_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/routines_screen.dart';
import 'package:repforge/services/workout_provider.dart';
import '../test_utils/mock_storage_service.dart';
import '../test_utils/mock_ml_service.dart';

void main() {
  group('RoutinesScreen Widget Tests', () {
    late WorkoutProvider workoutProvider;

    setUp(() {
      final mockStorage = MockStorageService();
      workoutProvider = WorkoutProvider(
        mockStorage,
        mlService: MockMLService(),
        programManager: ProgramManager(mockStorage),
      );

      // Create dummy exercises and routines
      workoutProvider.createRoutine('Test Routine 1', []);
    });

    Widget createTestWidget() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<WorkoutProvider>.value(value: workoutProvider),
        ],
        child: const MaterialApp(
          home: RoutinesScreen(),
        ),
      );
    }

    testWidgets('should display clone routine option and open dialog', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find the first routine
      expect(find.text('Test Routine 1'), findsOneWidget);

      // Long press the card to trigger the bottom sheet
      await tester.longPress(find.text('Test Routine 1'));
      await tester.pumpAndSettle();

      // Verify "Clone Routine" option appears in the bottom sheet
      expect(find.text('Clone Routine'), findsOneWidget);

      // Tap on the Clone Routine option
      await tester.tap(find.text('Clone Routine'));
      await tester.pumpAndSettle();

      // Verify the clone dialog opens with correct pre-filled text
      expect(find.text('Clone Routine'), findsWidgets);
      expect(find.text('Test Routine 1'), findsWidgets);
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
