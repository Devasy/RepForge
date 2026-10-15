import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:repforge/services/exercise_guide_cache.dart';

class _StalledClient extends http.BaseClient {
  _StalledClient(this.handler);
  final Future<http.StreamedResponse> Function() handler;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => handler();
}

class _CloseTrackingClient extends MockClient {
  _CloseTrackingClient() : super((_) async => http.Response('', 200));
  bool closed = false;
  @override
  void close() => closed = true;
}

void main() {
  late Directory root;
  setUp(() async => root = await Directory.systemTemp.createTemp('guides_'));
  tearDown(() async => root.delete(recursive: true));

  final jpeg = [0xff, 0xd8, 0xff, 0xd9];

  test('closing a cache leaves an injected client under caller ownership', () {
    final client = _CloseTrackingClient();
    final cache = ExerciseGuideCache(client: client);
    cache.close();
    expect(client.closed, isFalse);
    client.close();
    expect(client.closed, isTrue);
  });

  test(
    'bulk download caches only curated images and skips them on retry',
    () async {
      var requests = 0;
      final cache = ExerciseGuideCache(
        directory: () async => root,
        client: MockClient((_) async {
          requests++;
          return http.Response.bytes(jpeg, 200);
        }),
      );
      final progress = <int>[];
      await cache.downloadAll(onProgress: (done, _) => progress.add(done));
      expect(progress, [1, 2, 3, 4, 5, 6]);
      expect(requests, 12);
      expect(await cache.isDownloaded('bench_press'), isTrue);
      await cache.downloadAll();
      expect(requests, 12);
      await expectLater(cache.fileFor('../outside', 0), throwsArgumentError);
    },
  );

  test('invalid response is not cached and a later retry succeeds', () async {
    var valid = false;
    final cache = ExerciseGuideCache(
      directory: () async => root,
      client: MockClient(
        (_) async => http.Response.bytes(valid ? jpeg : [0, 1, 2, 3], 200),
      ),
    );
    await expectLater(cache.download('push_ups'), throwsFormatException);
    expect(await cache.isDownloaded('push_ups'), isFalse);
    valid = true;
    await cache.download('push_ups');
    expect(await cache.isDownloaded('push_ups'), isTrue);
  });

  test(
    'a stalled request or body times out so the download can be retried',
    () async {
      final requestCache = ExerciseGuideCache(
        directory: () async => root,
        timeout: const Duration(milliseconds: 10),
        client: _StalledClient(() => Completer<http.StreamedResponse>().future),
      );
      await expectLater(
        requestCache.download('push_ups'),
        throwsA(isA<TimeoutException>()),
      );

      final body = StreamController<List<int>>();
      addTearDown(body.close);
      final bodyCache = ExerciseGuideCache(
        directory: () async => root,
        timeout: const Duration(milliseconds: 10),
        client: _StalledClient(
          () async => http.StreamedResponse(body.stream, 200),
        ),
      );
      await expectLater(
        bodyCache.download('push_ups'),
        throwsA(isA<TimeoutException>()),
      );
      expect(await bodyCache.isDownloaded('push_ups'), isFalse);
    },
  );
}
