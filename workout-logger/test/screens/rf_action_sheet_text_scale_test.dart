// Guards showRFActionSheet against large system font sizes and short
// viewports. showModalBottomSheet defaults to isScrollControlled: false, which
// caps the sheet at 9/16 of the viewport — enough that a three-action sheet
// with descriptions clipped its last action, with no way to scroll to it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/screens/widgets/rf_dialogs.dart';
import 'package:repforge/theme/app_theme.dart';

/// 1.0 is the default; 2.0 is the largest Android's accessibility settings
/// offer. 400x640 is a short viewport, where the 9/16 cap bites hardest.
const _textScales = <double>[1.0, 1.35, 2.0];
const _viewport = Size(400, 640);

enum _Choice { save, discard, cancel }

void main() {
  Future<void> openSheet(WidgetTester tester, double textScale) async {
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: _viewport,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showRFActionSheet<_Choice>(
                    context,
                    title: 'Leave this workout?',
                    message:
                        'You have unsaved sets in this session. Choose what '
                        'to do with them before you go.',
                    actions: const [
                      RFAction(
                        label: 'Save and leave',
                        value: _Choice.save,
                        description:
                            'Finish the workout here and keep every set you '
                            'have logged so far.',
                        isPrimary: true,
                      ),
                      RFAction(
                        label: 'Discard workout',
                        value: _Choice.discard,
                        description:
                            'Throw away this session and everything logged '
                            'in it. This cannot be undone.',
                        isDanger: true,
                      ),
                      RFAction(label: 'Keep going', value: _Choice.cancel),
                    ],
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  for (final scale in _textScales) {
    testWidgets('action sheet lays out without overflow at ${scale}x text',
        (tester) async {
      tester.view.physicalSize = _viewport;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await openSheet(tester, scale);

      // A RenderFlex overflow is reported as a FlutterError during layout, so
      // reaching this point with a clean exception state is the assertion.
      expect(tester.takeException(), isNull);
      expect(find.text('Leave this workout?'), findsOneWidget);
    });

    testWidgets('every action stays reachable at ${scale}x text',
        (tester) async {
      tester.view.physicalSize = _viewport;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await openSheet(tester, scale);

      // The last action is the one the 9/16 cap used to cut off. Scroll it
      // into view rather than asserting it is already visible: the sheet is
      // legitimately taller than the viewport at 2.0x.
      final lastAction = find.text('Keep going');
      await tester.scrollUntilVisible(
        lastAction,
        80,
        scrollable: find.byType(Scrollable).last,
      );
      expect(lastAction, findsOneWidget);

      await tester.tap(lastAction);
      await tester.pumpAndSettle();

      // Tapping it dismissed the sheet, so it was genuinely hittable.
      expect(find.text('Leave this workout?'), findsNothing);
    });
  }
}
