import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/widgets/rf_question_card.dart';
import 'package:repforge/theme/app_theme.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.darkTheme,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  group('RFQuestionCard', () {
    final singleSpec = QuestionSpec(
      question: 'What is your goal?',
      options: ['Strength', 'Hypertrophy', 'Fat loss'],
    );

    final multiSpec = QuestionSpec(
      question: 'Which changes to apply?',
      options: ['Reorder', 'Add exercise', 'Replace exercise'],
      multiSelect: true,
    );

    testWidgets('renders question text and options', (tester) async {
      await tester.pumpWidget(_wrap(
        RFQuestionCard(
          questions: [singleSpec],
          onSubmit: (_) {},
        ),
      ));
      expect(find.text('What is your goal?'), findsOneWidget);
      expect(find.text('Strength'), findsOneWidget);
      expect(find.text('Hypertrophy'), findsOneWidget);
      expect(find.text('Fat loss'), findsOneWidget);
    });

    testWidgets('single-select: tapping second chip deselects first', (tester) async {
      List<AnswerSpec>? submitted;
      await tester.pumpWidget(_wrap(
        RFQuestionCard(
          questions: [singleSpec],
          onSubmit: (a) => submitted = a,
        ),
      ));

      await tester.tap(find.text('Strength'));
      await tester.pump();
      await tester.tap(find.text('Hypertrophy'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(submitted, isNotNull);
      expect(submitted!.first.selected, ['Hypertrophy']);
    });

    testWidgets('multi-select: multiple chips stay selected', (tester) async {
      List<AnswerSpec>? submitted;
      await tester.pumpWidget(_wrap(
        RFQuestionCard(
          questions: [multiSpec],
          onSubmit: (a) => submitted = a,
        ),
      ));

      await tester.tap(find.text('Reorder'));
      await tester.pump();
      await tester.tap(find.text('Add exercise'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(submitted!.first.selected, containsAll(['Reorder', 'Add exercise']));
    });

    testWidgets('custom text is included in answer when typed', (tester) async {
      List<AnswerSpec>? submitted;
      await tester.pumpWidget(_wrap(
        RFQuestionCard(
          questions: [singleSpec],
          onSubmit: (a) => submitted = a,
        ),
      ));

      await tester.enterText(find.byType(TextField), 'Power lifting');
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(submitted!.first.custom, 'Power lifting');
    });

    testWidgets('multiple questions rendered and submitted together', (tester) async {
      List<AnswerSpec>? submitted;
      await tester.pumpWidget(_wrap(
        RFQuestionCard(
          questions: [singleSpec, multiSpec],
          onSubmit: (a) => submitted = a,
        ),
      ));

      expect(find.text('What is your goal?'), findsOneWidget);
      expect(find.text('Which changes to apply?'), findsOneWidget);

      await tester.tap(find.text('Strength'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(submitted, hasLength(2));
      expect(submitted![0].question, 'What is your goal?');
      expect(submitted![1].question, 'Which changes to apply?');
    });
  });
}
