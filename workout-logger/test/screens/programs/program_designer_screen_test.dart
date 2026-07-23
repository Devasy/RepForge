import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/screens/programs/program_designer_screen.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';
import '../../test_utils/mock_storage_service.dart';
import '../../test_utils/mock_ml_service.dart';
import '../../test_utils/test_harness.dart';

Future<WorkoutProvider> _createProvider() async {
  final storage = MockStorageService();
  final provider = WorkoutProvider(
    storage,
    mlService: MockMLService(),
    programManager: ProgramManager(storage),
  );
  await provider.init();
  return provider;
}

void main() {
  testWidgets('Renders Step 1 metadata controls in ProgramDesignerScreen', (WidgetTester tester) async {
    await TestHarness.prepareTester(tester);

    final provider = await _createProvider();

    await tester.pumpWidget(TestHarness.wrap(
      const ProgramDesignerScreen(),
      workoutProvider: provider,
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('New Program'), findsOneWidget);
    expect(find.text('PROGRAM DETAILS'), findsOneWidget);
    expect(find.text('Step 1 of 3'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('Shows validation error if program name is empty on Next', (WidgetTester tester) async {
    await TestHarness.prepareTester(tester);

    final provider = await _createProvider();

    await tester.pumpWidget(TestHarness.wrap(
      const ProgramDesignerScreen(),
      workoutProvider: provider,
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    // Tap Next without filling program name
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    tester.takeException();

    // Step 1 stays active because name is empty
    expect(find.text('Step 1 of 3'), findsOneWidget);
  });

  testWidgets('Enters program name and navigates to Step 2', (WidgetTester tester) async {
    await TestHarness.prepareTester(tester);

    final provider = await _createProvider();

    await tester.pumpWidget(TestHarness.wrap(
      const ProgramDesignerScreen(),
      workoutProvider: provider,
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    // Enter Program Name
    final nameField = find.widgetWithText(TextField, 'Program Name *');
    await tester.enterText(nameField, 'Hypertrophy 101');
    await tester.pump();

    // Tap Next
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(find.text('WEEKS & DAYS'), findsOneWidget);
  });
}
