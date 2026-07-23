import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repforge/screens/ai_program_generator_screen.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/ai/gemini_ai_service.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/managers/pr_manager.dart';
import 'package:repforge/services/interfaces/ml_service_interface.dart';
import '../test_utils/mock_storage_service.dart';
import '../test_utils/mock_ml_service.dart';

Widget _wrapWithProviders({
  required WorkoutProvider workoutProvider,
  required ProgramManager programManager,
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
      ChangeNotifierProvider<ProgramManager>.value(value: programManager),
      ChangeNotifierProvider<GeminiAiService>.value(value: GeminiAiService()),
      Provider<IMLService>.value(value: MockMLService()),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('Renders AiProgramGeneratorScreen title and suggestion chips', (WidgetTester tester) async {
    final storage = MockStorageService();
    final pm = ProgramManager(storage);
    final workout = WorkoutProvider(storage, mlService: MockMLService(), programManager: pm);
    await workout.init();

    await tester.pumpWidget(_wrapWithProviders(
      workoutProvider: workout,
      programManager: pm,
      child: const AiProgramGeneratorScreen(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('AI Program Generator'), findsOneWidget);
    expect(find.text('12-week hypertrophy, 4 days/week, push-pull-legs-upper'), findsOneWidget);
  });

  testWidgets('Selecting a suggestion chip populates text field', (WidgetTester tester) async {
    final storage = MockStorageService();
    final pm = ProgramManager(storage);
    final workout = WorkoutProvider(storage, mlService: MockMLService(), programManager: pm);
    await workout.init();

    await tester.pumpWidget(_wrapWithProviders(
      workoutProvider: workout,
      programManager: pm,
      child: const AiProgramGeneratorScreen(),
    ));
    await tester.pumpAndSettle();

    final chip = find.text('12-week hypertrophy, 4 days/week, push-pull-legs-upper');
    await tester.tap(chip);
    await tester.pump();

    final textField = find.widgetWithText(TextField, '12-week hypertrophy, 4 days/week, push-pull-legs-upper');
    expect(textField, findsOneWidget);
  });
}
