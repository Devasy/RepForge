import 'dart:async';

import 'package:flutter/material.dart';
import 'dart:ui' show Tristate;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/screens/widgets/rf_form_fields.dart';
import 'package:repforge/screens/widgets/rf_selection_group.dart';
import 'package:repforge/theme/app_theme.dart';

Widget _wrap(Widget child, {double textScale = 1, bool reduceMotion = false}) =>
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reduceMotion,
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      ),
    );

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(375, 812),
    const Size(844, 375),
    const Size(800, 1024),
  ]) {
    testWidgets(
      'shared controls fit $size with doubled text and reduced motion',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          _wrap(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RFSelectionGroup<int>(
                  options: const [
                    RFSelectionOption(value: 0, label: '1.25 kg'),
                    RFSelectionOption(value: 1, label: '2.5 kg'),
                    RFSelectionOption(value: 2, label: '5 kg'),
                    RFSelectionOption(value: 3, label: '10 kg'),
                  ],
                  selected: 1,
                  onChanged: (_) {},
                ),
                const SizedBox(height: 16),
                const RFTextField(
                  label: 'Exercise name',
                  errorText: 'Enter at least three characters.',
                ),
                const SizedBox(height: 16),
                RFDropdown<String>(
                  label: 'Coach model',
                  value: 'Gemini 3.6 Flash',
                  items: const [
                    'Gemini 3.6 Flash',
                    'Gemini 3.7 Flash with a longer model name',
                  ],
                  onChanged: (_) {},
                ),
              ],
            ),
            textScale: 2,
            reduceMotion: true,
          ),
        );
        await tester.pumpAndSettle();
        for (final button in find.byType(FilledButton).evaluate()) {
          expect(
            tester.getSize(find.byWidget(button.widget)).height,
            greaterThanOrEqualTo(48),
          );
        }
        await tester.ensureVisible(find.byType(RFDropdown<String>));
        await tester.tap(find.byType(RFDropdown<String>));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.text('Gemini 3.7 Flash with a longer model name').last,
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Gemini 3.7 Flash with a longer model name').hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'selection announces its state, supports keys and disables actions',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var selected = 0;
      var enabled = true;
      late StateSetter update;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return RFSelectionGroup<int>(
                options: const [
                  RFSelectionOption(value: 0, label: 'kg'),
                  RFSelectionOption(value: 1, label: 'lbs'),
                ],
                selected: selected,
                onChanged: enabled
                    ? (value) => setState(() => selected = value)
                    : null,
              );
            },
          ),
        ),
      );
      final lbs = find.widgetWithText(FilledButton, 'lbs');
      Focus.of(tester.element(find.text('lbs'))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(selected, 1);
      expect(
        tester.getSemantics(lbs).flagsCollection.isSelected,
        Tristate.isTrue,
      );
      update(() => enabled = false);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'kg'));
      expect(selected, 1);
      expect(
        tester.getSemantics(lbs).flagsCollection.isEnabled,
        Tristate.isFalse,
      );
      expect(
        tester.getSemantics(lbs).flagsCollection.isSelected,
        Tristate.isTrue,
      );
      semantics.dispose();
    },
  );

  testWidgets(
    'dropdown restores the displayed saved value after a rejected commit',
    (tester) async {
      final commit = Completer<void>();
      await tester.pumpWidget(
        _wrap(
          RFDropdown<String>(
            label: 'Coach model',
            value: 'Saved model',
            items: const ['Saved model', 'Other model'],
            onChanged: (_) async => commit.future,
          ),
        ),
      );
      await tester.tap(find.byType(RFDropdown<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other model').last);
      await tester.pumpAndSettle();
      commit.complete();
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Saved model',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dropdown supports keyboard selection and external value updates',
    (tester) async {
      var value = 0;
      late StateSetter update;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return RFDropdown<int>(
                label: 'Day of week',
                value: value,
                items: const [0, 1],
                labelBuilder: (day) => day == 0 ? 'Unscheduled' : 'Monday',
                onChanged: (day) => setState(() => value = day!),
              );
            },
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(value, 1);
      update(() => value = 0);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Unscheduled',
      );
    },
  );

  testWidgets('shared form keeps inline validation and editing focus', (
    tester,
  ) async {
    final form = GlobalKey<FormState>();
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _wrap(
        Form(
          key: form,
          child: RFTextFormField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Exercise name'),
            validator: (value) => value == null || value.length < 3
                ? 'Enter at least three characters.'
                : null,
          ),
        ),
      ),
    );
    expect(form.currentState!.validate(), isFalse);
    await tester.pumpAndSettle();
    expect(find.text('Enter at least three characters.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Bench press');
    expect(form.currentState!.validate(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Enter at least three characters.'), findsNothing);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
  });

  test('selected labels and control boundaries meet contrast requirements', () {
    double contrast(Color first, Color second) {
      final a = first.computeLuminance();
      final b = second.computeLuminance();
      return a > b ? (a + 0.05) / (b + 0.05) : (b + 0.05) / (a + 0.05);
    }

    expect(
      contrast(AppColors.onControlSelected, AppColors.controlSelected),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(AppColors.controlOutline, AppColors.cardHigh),
      greaterThanOrEqualTo(3),
    );
    expect(
      contrast(AppColors.controlFocus, AppColors.cardHigh),
      greaterThanOrEqualTo(3),
    );
    expect(
      contrast(AppColors.controlError, AppColors.cardHigh),
      greaterThanOrEqualTo(4.5),
    );
  });
}
