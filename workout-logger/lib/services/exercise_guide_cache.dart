import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../data/exercise_demonstrations.dart';

/// App-private cache for the fixed set of curated exercise photos.
class ExerciseGuideCache {
  ExerciseGuideCache({
    http.Client? client,
    Future<Directory> Function()? directory,
  }) : _client = client ?? http.Client(),
       _directory = directory ?? getApplicationSupportDirectory;

  static final instance = ExerciseGuideCache();
  static const maxImageBytes = 5 * 1024 * 1024;
  final http.Client _client;
  final Future<Directory> Function() _directory;

  Future<File> fileFor(String exerciseId, int index) async {
    final guide = exerciseDemonstrations[exerciseId];
    if (guide == null || index < 0 || index >= guide.images.length) {
      throw ArgumentError('Unknown guide image');
    }
    final root = await _directory();
    return File('${root.path}/exercise_guides/${exerciseId}_$index.jpg');
  }

  Future<bool> isDownloaded(String exerciseId) async {
    final guide = exerciseDemonstrations[exerciseId];
    if (guide == null) return false;
    for (var i = 0; i < guide.images.length; i++) {
      if (!await (await fileFor(exerciseId, i)).exists()) return false;
    }
    return true;
  }

  Future<void> download(String exerciseId) async {
    final guide = exerciseDemonstrations[exerciseId];
    if (guide == null) throw ArgumentError('Unknown guide');
    for (var i = 0; i < guide.images.length; i++) {
      final file = await fileFor(exerciseId, i);
      if (await file.exists()) continue;
      final uri = Uri.parse(guide.images[i]);
      final response = await _client.send(http.Request('GET', uri));
      if (response.statusCode != 200) {
        throw HttpException(
          'Guide download failed: ${response.statusCode}',
          uri: uri,
        );
      }
      final bytes = <int>[];
      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        if (bytes.length > maxImageBytes) {
          throw const FormatException('Guide image is too large');
        }
      }
      if (bytes.length < 4 ||
          bytes[0] != 0xff ||
          bytes[1] != 0xd8 ||
          bytes[bytes.length - 2] != 0xff ||
          bytes.last != 0xd9) {
        throw const FormatException('Guide image is not a JPEG');
      }
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.part');
      try {
        await temporary.writeAsBytes(bytes, flush: true);
        await temporary.rename(file.path);
      } finally {
        if (await temporary.exists()) await temporary.delete();
      }
    }
  }

  /// Existing images are skipped, so a failed bulk download can be retried.
  Future<void> downloadAll({
    void Function(int completed, int total)? onProgress,
  }) async {
    final ids = exerciseDemonstrations.keys.toList();
    for (var i = 0; i < ids.length; i++) {
      await download(ids[i]);
      onProgress?.call(i + 1, ids.length);
    }
  }
}
