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
    await tester.pumpAndSettle();
    expect(find.text('Success Toast'), findsOneWidget);

    await tester.tap(find.text('Warning'));
    await tester.pumpAndSettle();
    expect(find.text('Warning Toast'), findsOneWidget);

    await tester.tap(find.text('Error'));
    await tester.pumpAndSettle();
    expect(find.text('Error Toast'), findsOneWidget);

    await tester.tap(find.text('Info'));
    await tester.pumpAndSettle();
    expect(find.text('Info Toast'), findsOneWidget);
  });

  testWidgets('showRFConfirmDialog renders normal and danger confirmation dialogs', (tester) async {
    bool? dangerResult;
    bool? cancelResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                ElevatedButton(
                  onPressed: () async {
                    dangerResult = await showRFConfirmDialog(
                      context,
                      title: 'Delete Item',
                      content: 'Are you sure you want to delete?',
                      isDanger: true,
                      confirmText: 'Delete',
                    );
                  },
                  child: const Text('Open Danger Dialog'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    cancelResult = await showRFConfirmDialog(
                      context,
                      title: 'Confirm Action',
                      content: 'Do you want to proceed?',
                      isDanger: false,
                      confirmText: 'Proceed',
                    );
                  },
                  child: const Text('Open Normal Dialog'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Test danger confirmation path
    await tester.tap(find.text('Open Danger Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Item'), findsOneWidget);
    expect(find.text('Are you sure you want to delete?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(dangerResult, isTrue);

    // Test default non-danger styling path and cancellation behavior
    await tester.tap(find.text('Open Normal Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm Action'), findsOneWidget);
    expect(find.text('Do you want to proceed?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(cancelResult, isFalse);
  });
}
