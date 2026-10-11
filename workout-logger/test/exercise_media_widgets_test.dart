import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/add_custom_exercise_screen.dart';
import 'package:repforge/screens/widgets/exercise_demonstration_section.dart';
import 'package:repforge/screens/widgets/exercise_media_gallery.dart';
import 'package:repforge/services/exercise_media_store.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'test_utils/mock_storage_service.dart';

class _Store extends ExerciseMediaStore {
  _Store(Directory directory, this.fixture) : super(directory: directory);
  final ExerciseMedia fixture;
  int downloads = 0;
  bool fail = false;
  @override
  Future<ExerciseMedia> importFile(String path) async => fixture;
  @override
  Future<List<ExerciseMedia>> downloadGuide(
    List<Uri> urls, {
    bool Function(String)? isReferenced,
  }) async {
    downloads++;
    if (fail) throw const FormatException('offline');
    return [fixture];
  }
}

void main() {
  late Directory directory;
  late WorkoutProvider provider;
  late MockStorageService storage;
  late _Store store;
  late ExerciseMediaStore original;

  Future<void> setup(WidgetTester tester) async {
    original = ExerciseMediaStore.instance;
    directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('repforge-media-ui-'),
    ))!;
    final real = ExerciseMediaStore(directory: directory);
    final media = (await tester.runAsync(
      () => real.importImage(
        base64Decode(
          'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
        ),
      ),
    ))!;
    store = _Store(directory, media);
    ExerciseMediaStore.instance = store;
    storage = MockStorageService();
    provider = WorkoutProvider(
      storage,
      programManager: ProgramManager(storage),
    );
    await provider.init();
    addTearDown(() async {
      ExerciseMediaStore.instance = original;
      await directory.delete(recursive: true);
    });
  }

  Widget app(Widget child) => ChangeNotifierProvider.value(
    value: provider,
    child: MaterialApp(
      home: child is AddCustomExerciseScreen
          ? child
          : Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );

  testWidgets('guide never downloads on open; user tap attaches media', (
    tester,
  ) async {
    await setup(tester);
    await tester.pumpWidget(
      app(
        ExerciseDemonstrationSection(
          exercise: provider.getExercise('bench_press')!,
          provider: provider,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(store.downloads, 0);
    expect(find.text('Download photo guide'), findsOneWidget);
    expect(find.textContaining('Reference variant:'), findsOneWidget);
    await tester.tap(find.text('Download photo guide'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    expect(store.downloads, 1);
    expect(
      provider.getExercise('bench_press')!.media.single.fileName,
      store.fixture.fileName,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('failed download leaves exercise unchanged and allows retry', (
    tester,
  ) async {
    await setup(tester);
    store.fail = true;
    await tester.pumpWidget(
      app(
        ExerciseDemonstrationSection(
          exercise: provider.getExercise('squat')!,
          provider: provider,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Download photo guide'));
    await tester.pumpAndSettle();
    expect(provider.getExercise('squat')!.media, isEmpty);
    expect(find.textContaining('Could not save the guide'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'custom exercise without media offers editor instead of empty sheet',
    (tester) async {
      await setup(tester);
      await provider.addCustomExercise(
        name: 'Custom lift',
        category: 'compound',
        primaryMuscleGroupId: 'chest',
      );
      final exercise = provider.allExercises.firstWhere(
        (e) => e.name == 'Custom lift',
      );
      await tester.pumpWidget(
        app(
          ExerciseDemonstrationSection(exercise: exercise, provider: provider),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No demonstration added yet.'), findsOneWidget);
      expect(find.text('Add demonstration media'), findsOneWidget);
      expect(store.downloads, 0);
    },
  );

  testWidgets('editor picks a local attachment and persists it on Save', (
    tester,
  ) async {
    await setup(tester);
    const channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => [
        {
          'path': '${directory.path}/photo.gif',
          'name': 'photo.gif',
          'size': 43,
        },
      ],
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(
      app(
        AddCustomExerciseScreen(
          initialExercise: provider.getExercise('bench_press'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add photo, GIF, or video'));
    await tester.tap(find.text('Add photo, GIF, or video'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    expect(find.byType(ExerciseMediaPreview), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(
      storage.lastSavedExercise!.media.single.fileName,
      store.fixture.fileName,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
  });

  testWidgets(
    'editor removes attachment without changing other exercise fields',
    (tester) async {
      await setup(tester);
      await provider.updateExercise(id: 'bench_press', media: [store.fixture]);
      await tester.pumpWidget(
        app(
          AddCustomExerciseScreen(
            initialExercise: provider.getExercise('bench_press'),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
      await tester.ensureVisible(find.text('Remove media'));
      await tester.tap(find.text('Remove media'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(storage.lastSavedExercise!.media, isEmpty);
      expect(storage.lastSavedExercise!.name, 'Bench Press');
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
    },
  );
}
