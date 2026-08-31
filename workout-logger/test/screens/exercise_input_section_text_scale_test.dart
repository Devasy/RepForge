// Guards the set-entry UI against large system font sizes. A reader running
// Android's bigger-font settings was seeing the weight value clipped inside
// its own field and the assisted-load line run off the edge of its pill.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/widgets/exercise_input_section.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/theme/app_theme.dart';

import '../test_utils/mock_storage_service.dart';

/// Screen widths worth covering: a small phone, the common ~411dp phone, and a
/// tablet-ish width.
const _widths = <double>[360, 411, 720];

/// 1.0 is the default; 1.35 is roughly the reported device; 2.0 is the largest
/// font size Android's accessibility settings offer.
const _textScales = <double>[1.0, 1.35, 2.0];

void main() {
  late SettingsProvider settings;

  setUp(() async {
    settings = SettingsProvider(MockStorageService());
    await settings.init();
  });

  Widget harness({
    required double width,
    required double textScale,
    required double weight,
    String? exerciseId,
  }) {
    return MediaQuery(
      data: MediaQueryData(
        size: Size(width, 900),
        textScaler: TextScaler.linear(textScale),
      ),
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: SizedBox(
            width: width,
            height: 900,
            // Mirrors WorkoutFlowScreen: a scroll view tall enough for the
            // section's Spacer to have something to absorb.
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - AppSpacing.md * 2,
                  ),
                  child: IntrinsicHeight(
                    child: ExerciseInputSection(
                      contentWidth:
                          constraints.maxWidth - AppSpacing.md * 2,
                      currentWeight: weight,
                      currentReps: 12,
                      isDropset: false,
                      drops: const [],
                      mainWeightController: TextEditingController(),
                      mainRepsController: TextEditingController(),
                      dropWeightControllers: const [],
                      dropRepsControllers: const [],
                      recommendations: [
                        SetRecommendation(
                          weight: 19,
                          reps: 14,
                          confidence: 'high',
                          reasoning: 'test',
                        ),
                      ],
                      previousSets: const [],
                      lastSession: null,
                      settings: settings,
                      exerciseId: exerciseId,
                      onWeightChanged: (_) {},
                      onRepsChanged: (_) {},
                      onDropsetToggled: (_) {},
                      onDropAdded: () {},
                      onDropRemoved: (_) {},
                      onDropWeightChanged: (_, _) {},
                      onDropRepsChanged: (_, _) {},
                      onApplyRecommendation: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('ExerciseInputSection lays out without overflow', () {
    for (final width in _widths) {
      for (final scale in _textScales) {
        testWidgets('${width.toInt()}dp at ${scale}x text scale',
            (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          // A three-digit weight is the widest the field ever has to show.
          await tester.pumpWidget(harness(
            width: width,
            textScale: scale,
            weight: 102.5,
            exerciseId: 'pull_ups',
          ));
          await tester.pump();

          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('value text is fitted rather than clipped', () {
    testWidgets('a three-digit weight paints inside its field', (tester) async {
      tester.view.physicalSize = const Size(411, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(
        width: 411,
        textScale: 1.35,
        weight: 102.5,
      ));
      await tester.pump();

      final field = find.widgetWithText(TextField, '102.5');
      expect(field, findsOneWidget);

      final fieldWidth = tester.getSize(field).width;
      final style = tester.widget<TextField>(field).style!;
      final painter = TextPainter(
        text: TextSpan(text: '102.5', style: style),
        textDirection: TextDirection.ltr,
        textScaler: const TextScaler.linear(1.35),
      )..layout();

      expect(painter.width, lessThanOrEqualTo(fieldWidth));
      // Still shrunk only as far as it had to be.
      expect(style.fontSize, greaterThanOrEqualTo(18.0));
    });

    testWidgets('a short value keeps the full display size', (tester) async {
      tester.view.physicalSize = const Size(411, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(width: 411, textScale: 1.0, weight: 20));
      await tester.pump();

      final field = find.widgetWithText(TextField, '20.0');
      expect(field, findsOneWidget);
      expect(tester.widget<TextField>(field).style!.fontSize, 36.0);
    });
  });
}
