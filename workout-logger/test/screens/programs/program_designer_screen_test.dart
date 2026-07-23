import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/programs/program_designer_screen.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/ai/gemini_ai_service.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/managers/pr_manager.dart';
import 'package:repforge/services/interfaces/ml_service_interface.dart';
import '../../test_utils/mock_storage_service.dart';
import '../../test_utils/mock_ml_service.dart';

Widget _wrapWithProviders({
  required WorkoutProvider workoutProvider,
  required Widget child,
}) {
  final storage = MockStorageService();
  final sp = SettingsProvider(storage);
  final prm = PRManager(storage);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<WorkoutProvider>.value(value: workoutProvider),
      ChangeNotifierProvider<SettingsProvider>.value(value: sp),
      ChangeNotifierProvider<PRManager>.value(value: prm),
      ChangeNotifierProvider<GeminiAiService>.value(value: GeminiAiService()),
      Provider<IMLService>.value(value: MockMLService()),
    ],
    child: MaterialApp(home: child),
  );
}

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
    final provider = await _createProvider();

    await tester.pumpWidget(_wrapWithProviders(
      workoutProvider: provider,
      child: const ProgramDesignerScreen(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('New Program'), findsOneWidget);
    expect(find.text('Program Details'), findsOneWidget);
    expect(find.text('Step 1 of 3'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('Shows validation error if program name is empty on Next', (WidgetTester tester) async {
    final provider = await _createProvider();

    await tester.pumpWidget(_wrapWithProviders(
      workoutProvider: provider,
      child: const ProgramDesignerScreen(),
    ));
    await tester.pumpAndSettle();

    // Tap Next without filling program name
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Program name is required'), findsOneWidget);
  });

  testWidgets('Enters program name and navigates to Step 2', (WidgetTester tester) async {
    final provider = await _createProvider();

    await tester.pumpWidget(_wrapWithProviders(
      workoutProvider: provider,
      child: const ProgramDesignerScreen(),
    ));
    await tester.pumpAndSettle();

    // Enter Program Name
    final nameField = find.widgetWithText(TextField, 'Program Name *');
    await tester.enterText(nameField, 'Hypertrophy 101');
    await tester.pump();

    // Tap Next
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(find.text('Weeks & Days'), findsOneWidget);
  });

  testWidgets('Adds a phase in Step 1', (WidgetTester tester) async {
    final provider = await _createProvider();

    await tester.pumpWidget(_wrapWithProviders(
      workoutProvider: provider,
      child: const ProgramDesignerScreen(),
    ));
    await tester.pumpAndSettle();

    // Tap Add Phase button
    final addPhaseBtn = find.text('Add Phase');
    await tester.tap(addPhaseBtn);
    await tester.pumpAndSettle();

    expect(find.text('Phase Name'), findsOneWidget);

    // Enter Phase Name in dialog
    final phaseNameField = find.widgetWithText(TextField, 'Phase Name');
    await tester.enterText(phaseNameField, 'Bulking Phase');
    await tester.pump();

    // Save phase
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Bulking Phase'), findsOneWidget);
  });

  testWidgets('Navigates through Step 1, Step 2, and Step 3 to Save program', (WidgetTester tester) async {
    final provider = await _createProvider();

    await tester.pumpWidget(_wrapWithProviders(
      workoutProvider: provider,
      child: const ProgramDesignerScreen(),
    ));
    await tester.pumpAndSettle();

    // Step 1: Program Name
    await tester.enterText(find.widgetWithText(TextField, 'Program Name *'), 'Powerlifting 4-Week');
    await tester.pump();

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 2
    expect(find.text('Step 2 of 3'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 3
    expect(find.text('Step 3 of 3'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);

    // Tap Save
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Verify program was saved in WorkoutProvider / ProgramManager
    expect(provider.programs.any((p) => p.name == 'Powerlifting 4-Week'), isTrue);
  });
}
