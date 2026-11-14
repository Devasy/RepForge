import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:repforge/screens/programs/import_program_screen.dart';

import 'test_utils/fake_file_picker.dart';
import 'test_utils/test_robot.dart';

void main() {
  const program =
      '{"name":"Picked program","totalWeeks":1,"phases":[],"weeks":[]}';

  for (final scenario in ['selected', 'cancelled', 'unreadable']) {
    testWidgets('program file picker handles $scenario', (tester) async {
      final originalPicker = FilePickerPlatform.instance;
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('repforge-program-picker-'),
      ))!;
      final file = File('${directory.path}/program.json');
      if (scenario == 'selected') {
        await tester.runAsync(() => file.writeAsString(program));
      }
      FilePickerPlatform.instance = FakeFilePicker(
        scenario == 'cancelled' ? null : TestPickedFile(file),
      );
      addTearDown(() async {
        FilePickerPlatform.instance = originalPicker;
        await tester.runAsync(() => directory.delete(recursive: true));
      });

      await TestRobot(tester).pumpScreen(const ImportProgramScreen());
      await tester.enterText(find.byType(TextField), program);
      await tester.pump();
      await tester.tap(find.text('Validate'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Import'),
            )
            .onPressed,
        isNotNull,
      );

      await tester.tap(find.byTooltip('Pick JSON file'));
      await tester.pump();
      for (var attempt = 0; attempt < 50; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
        if (scenario == 'cancelled' ||
            (scenario == 'selected' &&
                tester
                        .widget<ElevatedButton>(
                          find.widgetWithText(ElevatedButton, 'Import'),
                        )
                        .onPressed ==
                    null) ||
            find.textContaining('Could not read file:').evaluate().isNotEmpty) {
          break;
        }
      }

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        program,
      );
      final importButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Import'),
      );
      if (scenario == 'selected') {
        expect(
          importButton.onPressed,
          isNull,
          reason: 'Picking a file clears the previous validation.',
        );
        await tester.tap(find.text('Validate'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Import'),
              )
              .onPressed,
          isNotNull,
        );
      } else {
        expect(
          importButton.onPressed,
          isNotNull,
          reason: 'Cancellation and read errors preserve the validated input.',
        );
      }
      expect(
        find.textContaining('Could not read file:'),
        scenario == 'unreadable' ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
