import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repforge/screens/widgets/extended_library_download.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'test_utils/mock_storage_service.dart';
import 'test_utils/mock_ml_service.dart';

void main() {
  testWidgets(
    'failed download offers retry and successful download enables offline exercises',
    (tester) async {
      final storage = MockStorageService();
      final provider = WorkoutProvider(
        storage,
        mlService: MockMLService(),
        programManager: ProgramManager(storage),
      );
      await provider.init();
      addTearDown(provider.dispose);
      var attempts = 0;
      final json = File('../catalogues/fitify-v1.json').readAsStringSync();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            home: Scaffold(
              body: ExtendedLibraryDownload(
                download: () async {
                  attempts++;
                  if (attempts == 1) throw StateError('Offline');
                  return json;
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Download extended library'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Could not load the library.'),
        findsOneWidget,
      );
      expect(provider.allExercises, hasLength(44));
      await tester.tap(find.text('Download extended library'));
      await tester.pumpAndSettle();
      expect(find.text('Extended library available offline'), findsOneWidget);
      expect(provider.allExercises, hasLength(949));
      expect(attempts, 2);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
    },
  );
}
