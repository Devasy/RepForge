import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:repforge/data/exercise_database.dart';
import 'package:repforge/data/exercise_demonstrations.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/backup_codec.dart';
import 'package:repforge/services/exercise_media_store.dart';

final tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNQaPj/HwAFAgKfdqhGyQAAAABJRU5ErkJggg==',
);
final tinyGif = base64Decode(
  'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late ExerciseMediaStore store;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('repforge-media-');
    store = ExerciseMediaStore(directory: dir);
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });

  test('legacy exercises have no media; copyWith can remove media', () {
    final exercise = ExerciseDatabase.getById('bench_press')!;
    expect(Exercise.fromJson(exercise.toJson()).media, isEmpty);
    final media = ExerciseMedia(
      fileName: '${sha256.convert(tinyPng)}.png',
      kind: ExerciseMediaKind.image,
    );
    final updated = exercise.copyWith(media: [media]);
    expect(
      Exercise.fromJson(updated.toJson()).media.single.fileName,
      media.fileName,
    );
    expect(updated.copyWith(media: []).media, isEmpty);
  });

  test(
    'rejects traversal, wrong extensions, unknown sources and long videos',
    () {
      for (final row in [
        {'fileName': '../../outside.png', 'kind': 'image'},
        {'fileName': '${sha256.convert(tinyPng)}.mp4', 'kind': 'image'},
        {
          'fileName': '${sha256.convert(tinyPng)}.png',
          'kind': 'image',
          'source': 'unknown',
        },
        {
          'fileName': '${sha256.convert(tinyPng)}.mp4',
          'kind': 'video',
          'durationMs': 60001,
        },
      ]) {
        expect(
          () => ExerciseMedia.fromJson(row),
          throwsA(isA<FormatException>()),
        );
      }
    },
  );

  test(
    'photos are re-encoded to private content-addressed PNG and deduplicated',
    () async {
      final first = await store.importImage(tinyPng);
      final second = await store.importImage(tinyPng);
      expect(first.fileName, second.fileName);
      expect(first.kind, ExerciseMediaKind.image);
      expect(first.fileName, matches(RegExp(r'^[a-f0-9]{64}\.png$')));
      expect(await (await store.fileFor(first)).exists(), isTrue);
      expect(await dir.list().length, 1);
    },
  );

  test('GIF bytes retain their animation', () async {
    final media = await store.importImage(tinyGif);
    expect(media.kind, ExerciseMediaKind.gif);
    expect(await (await store.fileFor(media)).readAsBytes(), tinyGif);
  });

  test('invalid and oversized images are rejected without files', () async {
    await expectLater(
      store.importImage(Uint8List.fromList([1, 2, 3])),
      throwsA(anything),
    );
    await expectLater(
      store.importImage(Uint8List(ExerciseMediaStore.maxImageBytes + 1)),
      throwsFormatException,
    );
    expect(await dir.list().length, 0);
  });

  test(
    'backup embeds deduplicated bytes and restores into another directory',
    () async {
      final media = await store.importImage(tinyPng);
      final exercise = ExerciseDatabase.getById(
        'bench_press',
      )!.copyWith(media: [media]);
      final payload = {
        'backupFormatVersion': 1,
        'exerciseOverrides': [exercise.toJson()],
        'customExercises': [
          exercise.copyWith(id: 'custom_test', isCustom: true).toJson(),
        ],
      };
      final backup = await store.encodeBackup(payload);
      final decoded = decodeBackup(backup);
      expect(decoded['backupFormatVersion'], 2);
      expect((decoded['exerciseMedia'] as Map).length, 1);
      final destination = ExerciseMediaStore(
        directory: Directory('${dir.path}/new-device'),
      );
      await destination.restoreBackup(decoded);
      expect(
        await (await destination.fileFor(media)).readAsBytes(),
        await (await store.fileFor(media)).readAsBytes(),
      );
      expect(backup, isNot(contains(dir.path)));
    },
  );

  test('old backups need no media directory and remain version 1', () async {
    final result = await store.encodeBackup({
      'backupFormatVersion': 1,
      'sessions': [],
    });
    expect(decodeBackup(result)['backupFormatVersion'], 1);
    expect(
      () => decodeBackup('{"backupFormatVersion":99,"sessions":[]}'),
      throwsFormatException,
    );
  });

  test(
    'rejects missing, corrupt and unreferenced blobs before restore',
    () async {
      final media = await store.importImage(tinyPng);
      final row = ExerciseDatabase.getById(
        'bench_press',
      )!.copyWith(media: [media]).toJson();
      for (final blobs in [
        <String, String>{},
        {media.fileName: base64Encode(tinyGif)},
        {
          media.fileName: base64Encode(
            await (await store.fileFor(media)).readAsBytes(),
          ),
          'extra': 'AA==',
        },
      ]) {
        expect(
          () => decodeBackup(
            jsonEncode({
              'backupFormatVersion': 2,
              'exerciseOverrides': [row],
              'exerciseMedia': blobs,
            }),
          ),
          throwsFormatException,
        );
      }
      expect(
        () => decodeBackup(
          jsonEncode({
            'backupFormatVersion': 1,
            'exerciseOverrides': [row],
          }),
        ),
        throwsFormatException,
      );
      await (await store.fileFor(media)).delete();
      await expectLater(
        store.encodeBackup({
          'exerciseOverrides': [row],
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'cleanup preserves shared attachments and removes abandoned files',
    () async {
      final media = await store.importImage(tinyGif);
      await store.discardUnreferenced([media], (_) => true);
      expect(await (await store.fileFor(media)).exists(), isTrue);
      await store.discardUnreferenced([media], (_) => false);
      expect(await (await store.fileFor(media)).exists(), isFalse);
    },
  );

  test(
    'curated guides reference existing exact catalogue entries and pinned URLs',
    () {
      expect(exerciseDemonstrations.length, 6);
      for (final entry in exerciseDemonstrations.entries) {
        expect(ExerciseDatabase.getById(entry.key), isNotNull);
        expect(entry.value.images.length, 2);
        expect(entry.value.instructions, isNotEmpty);
        for (final url in entry.value.images) {
          expect(url, contains('f00c92c7dcf1216a928a52c3706c7ce8e2f71ed5'));
        }
      }
    },
  );

  test(
    'downloads only curated HTTPS origin and preserves source attribution',
    () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return http.Response.bytes(tinyPng, 200);
      });
      final network = ExerciseMediaStore(directory: dir, client: client);
      await expectLater(
        network.downloadGuide([Uri.parse('https://example.com/image.png')]),
        throwsFormatException,
      );
      expect(calls, 0);
      final items = await network.downloadGuide(
        exerciseDemonstrations['bench_press']!.images.map(Uri.parse).toList(),
      );
      expect(calls, 2);
      expect(items.every((m) => m.source == 'free-exercise-db'), isTrue);
      expect(await (await network.fileFor(items.first)).exists(), isTrue);
      client.close();
    },
  );

  test('failed HTTP download produces no references', () async {
    final client = MockClient((_) async => http.Response('Not found', 404));
    final network = ExerciseMediaStore(directory: dir, client: client);
    await expectLater(
      network.downloadGuide(
        exerciseDemonstrations['squat']!.images.map(Uri.parse).toList(),
      ),
      throwsFormatException,
    );
    expect(await dir.list().length, 0);
    client.close();
  });
  test(
    'video import enforces measured duration before storing files',
    () async {
      final selected = File('${dir.path}/selected.mp4');
      await selected.writeAsBytes([
        0,
        0,
        0,
        24,
        102,
        116,
        121,
        112,
        105,
        115,
        111,
        109,
      ]);
      final valid = ExerciseMediaStore(
        directory: Directory('${dir.path}/valid'),
        videoInspector: (_) async => 60000,
      );
      final media = await valid.importFile(selected.path);
      expect(media.kind, ExerciseMediaKind.video);
      expect(media.durationMs, 60000);
      expect(await (await valid.fileFor(media)).exists(), isTrue);
      final long = ExerciseMediaStore(
        directory: Directory('${dir.path}/long'),
        videoInspector: (_) async => 60001,
      );
      await expectLater(long.importFile(selected.path), throwsFormatException);
      expect(await Directory('${dir.path}/long').exists(), isFalse);
    },
  );

  test('partial guide failure cleans unreferenced first photo', () async {
    var calls = 0;
    final client = MockClient(
      (_) async => ++calls == 1
          ? http.Response.bytes(tinyPng, 200)
          : http.Response('unavailable', 503),
    );
    final network = ExerciseMediaStore(directory: dir, client: client);
    await expectLater(
      network.downloadGuide(
        exerciseDemonstrations['squat']!.images.map(Uri.parse).toList(),
        isReferenced: (_) => false,
      ),
      throwsFormatException,
    );
    expect(await dir.list().length, 0);
    client.close();
  });

  test('backup rejects oversized decoded image dimensions', () {
    final huge = Uint8List.fromList(tinyPng);
    final header = ByteData.sublistView(huge);
    header.setUint32(16, 100000);
    header.setUint32(20, 100000);
    final media = ExerciseMedia(
      fileName: '${sha256.convert(huge)}.png',
      kind: ExerciseMediaKind.image,
    );
    final row = ExerciseDatabase.getById(
      'bench_press',
    )!.copyWith(media: [media]).toJson();
    expect(
      () => decodeBackup(
        jsonEncode({
          'backupFormatVersion': 2,
          'exerciseOverrides': [row],
          'exerciseMedia': {media.fileName: base64Encode(huge)},
        }),
      ),
      throwsFormatException,
    );
  });
  test(
    'restore repairs a truncated or same-length corrupt destination',
    () async {
      final media = await store.importImage(tinyGif);
      final row = ExerciseDatabase.getById(
        'bench_press',
      )!.copyWith(media: [media]).toJson();
      final backup = decodeBackup(
        await store.encodeBackup({
          'exerciseOverrides': [row],
        }),
      );
      final destination = await store.fileFor(media);
      for (final corrupt in [
        Uint8List.fromList([1, 2, 3]),
        Uint8List(tinyGif.length),
      ]) {
        await destination.writeAsBytes(corrupt);
        await store.restoreBackup(backup);
        expect(await destination.readAsBytes(), tinyGif);
      }
      final previousModified = await destination.lastModified();
      await store.restoreBackup(backup);
      expect(await destination.lastModified(), previousModified);
    },
  );
}
