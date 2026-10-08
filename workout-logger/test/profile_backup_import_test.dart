import 'dart:async';
import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/screens/profile_screen.dart';
import 'package:repforge/services/backup_codec.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'test_utils/mock_storage_service.dart';
import 'test_utils/mock_ml_service.dart';
import 'test_utils/test_robot.dart';

class ImportStorage extends MockStorageService {
  final completed = Completer<void>();
  @override
  Future<void> importData(String source) async {
    try {
      final data = decodeBackup(source);
      for (final entry
          in (data['settings'] as Map<String, dynamic>? ?? {}).entries) {
        await saveSetting(entry.key, entry.value.toString());
      }
    } finally {
      completed.complete();
    }
  }
}

class RefreshSettings extends SettingsProvider {
  RefreshSettings(super.storage);
  bool failRefresh = false;
  @override
  Future<void> init() async {
    if (failRefresh) throw StateError('Refresh unavailable');
    await super.init();
  }
}

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'RepForge',
      packageName: 'com.devasy.repforge',
      version: '2.1.5',
      buildNumber: '63',
      buildSignature: '',
    );
  });
  for (final scenario in ['settings-only', 'refresh-failure', 'non-object']) {
    testWidgets('backup screen handles $scenario correctly', (tester) async {
      final storage = ImportStorage();
      final settings = RefreshSettings(storage);
      await settings.init();
      final workout = WorkoutProvider(
        storage,
        mlService: MockMLService(),
        programManager: ProgramManager(storage),
      );
      await workout.init();
      final directory = await tester.runAsync(
        () => Directory.systemTemp.createTemp('repforge-backup-ui-'),
      );
      final file = File('${directory!.path}/backup.json');
      await tester.runAsync(
        () => file.writeAsString(
          scenario == 'non-object'
              ? '[]'
              : '{"settings":{"userName":"Imported User"}}',
        ),
      );
      const channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => [
          {'path': file.path, 'name': 'backup.json', 'size': 64},
        ],
      );
      addTearDown(() async {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        );
        await tester.runAsync(() => directory.delete(recursive: true));
      });
      await TestRobot(tester).pumpScreen(
        const ProfileScreen(),
        storage: storage,
        settingsProvider: settings,
        workoutProvider: workout,
      );
      settings.failRefresh = scenario == 'refresh-failure';
      await tester.ensureVisible(find.text('Import Backup'));
      await tester.tap(find.text('Import Backup'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose File'));
      await tester.pump();
      for (
        var attempt = 0;
        attempt < 50 && !storage.completed.isCompleted;
        attempt++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(storage.completed.isCompleted, isTrue);
      await tester.pumpAndSettle();
      if (scenario == 'non-object') {
        expect(
          find.text('Import failed. Invalid backup file.'),
          findsOneWidget,
        );
      } else {
        expect(await storage.getSetting('userName'), 'Imported User');
        expect(find.text('Import failed. Invalid backup file.'), findsNothing);
        if (scenario == 'refresh-failure') {
          expect(
            find.text(
              'Backup merged, but some data did not refresh. Restart the app.',
            ),
            findsOneWidget,
          );
        } else {
          expect(
            find.textContaining('Backup merged: 0 sessions'),
            findsOneWidget,
          );
        }
      }
      expect(tester.takeException(), isNull);
    });
  }
}
