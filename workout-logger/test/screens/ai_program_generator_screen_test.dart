import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/screens/ai_program_generator_screen.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';
import '../test_utils/mock_storage_service.dart';
import '../test_utils/mock_ml_service.dart';
import '../test_utils/test_harness.dart';

void main() {
  testWidgets('Renders AiProgramGeneratorScreen title and suggestion chips', (WidgetTester tester) async {
    await TestHarness.prepareTester(tester);

    final storage = MockStorageService();
    final workout = WorkoutProvider(storage, mlService: MockMLService(), programManager: ProgramManager(storage));
    await workout.init();

    await tester.pumpWidget(TestHarness.wrap(
      const AiProgramGeneratorScreen(),
      storage: storage,
      workoutProvider: workout,
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('AI Program Generator'), findsOneWidget);

    final suggestionChip = find.text('12-week hypertrophy, 4 days/week, push-pull-legs-upper');
    expect(suggestionChip, findsWidgets);

    await tester.tap(suggestionChip.first);
    await tester.pumpAndSettle();
    tester.takeException();
  });
}
