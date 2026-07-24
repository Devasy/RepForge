import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/screens/widgets/rf_dialogs.dart';

void main() {
  testWidgets('showRFSnackBar displays all snackbar types correctly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                ElevatedButton(
                  onPressed: () => context.showRFSnackBar('Success Toast', type: RFSnackBarType.success),
                  child: const Text('Success'),
                ),
                ElevatedButton(
                  onPressed: () => context.showRFSnackBar('Warning Toast', type: RFSnackBarType.warning),
                  child: const Text('Warning'),
                ),
                ElevatedButton(
                  onPressed: () => context.showRFSnackBar('Error Toast', type: RFSnackBarType.error),
                  child: const Text('Error'),
                ),
                ElevatedButton(
                  onPressed: () => context.showRFSnackBar('Info Toast', type: RFSnackBarType.info),
                  child: const Text('Info'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Success'));
    await tester.pump();
    expect(find.text('Success Toast'), findsOneWidget);

    await tester.tap(find.text('Warning'));
    await tester.pump();
    expect(find.text('Warning Toast'), findsOneWidget);

    await tester.tap(find.text('Error'));
    await tester.pump();
    expect(find.text('Error Toast'), findsOneWidget);

    await tester.tap(find.text('Info'));
    await tester.pump();
    expect(find.text('Info Toast'), findsOneWidget);
  });

  testWidgets('showRFConfirmDialog renders normal and danger confirmation dialogs', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showRFConfirmDialog(
                  context,
                  title: 'Delete Item',
                  content: 'Are you sure you want to delete?',
                  isDanger: true,
                  confirmText: 'Delete',
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Item'), findsOneWidget);
    expect(find.text('Are you sure you want to delete?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
