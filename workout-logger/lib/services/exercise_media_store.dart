import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/exercise_media.dart';

/// Owns media bytes independently of exercise rows and portable backup references.
class ExerciseMediaStore {
  ExerciseMediaStore({
    Directory? directory,
    http.Client? client,
    Future<int?> Function(String)? videoInspector,
  }) : _directory = directory,
       _client = client,
       _videoInspector = videoInspector;

  static ExerciseMediaStore instance = ExerciseMediaStore();
  static const maxImageBytes = 12 * 1024 * 1024;
  static const maxVideoBytes = 30 * 1024 * 1024;
  static const maxBackupBytes = 80 * 1024 * 1024;
  static const maxItems = 4;
  static const _channel = MethodChannel('repforge/exercise_media');
  final Directory? _directory;
  final http.Client? _client;
  final Future<int?> Function(String)? _videoInspector;

  Future<Directory> get directory async {
    final dir =
        _directory ??
        Directory(
          '${(await getApplicationDocumentsDirectory()).path}/exercise_media',
        );
    await dir.create(recursive: true);
    return dir;
  }

  Future<File> fileFor(ExerciseMedia media) async {
    media.validate();
    return File('${(await directory).path}/${media.fileName}');
  }

  Future<ExerciseMedia> importFile(String path) async {
    final file = File(path);
    final size = await file.length();
    if (size <= 0 || size > maxVideoBytes) {
      throw const FormatException(
        'Choose an image under 12 MB or a video under 30 MB.',
      );
    }
    final bytes = await file.readAsBytes();
    if (_isMp4(bytes)) {
      if (!Platform.isAndroid && _videoInspector == null) {
        throw const FormatException(
          'Video demonstrations are supported on Android.',
        );
      }
      final duration = _videoInspector != null
          ? await _videoInspector(path)
          : await _channel.invokeMethod<int>('videoDuration', {'path': path});
      final media = await _write(
        bytes,
        ExerciseMediaKind.video,
        durationMs: duration,
      );
      return media;
    }
    return importImage(bytes);
  }

  /// Re-encoding photos strips EXIF/location metadata and limits display size.
  /// GIFs keep their original animation; they are never uploaded automatically.
  Future<ExerciseMedia> importImage(Uint8List bytes, {String? source}) async {
    if (bytes.isEmpty || bytes.length > maxImageBytes) {
      throw const FormatException('Choose an image under 12 MB.');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (descriptor.width * descriptor.height > 16000000) {
        throw const FormatException(
          'Image dimensions are too large (maximum 16 megapixels).',
        );
      }
      if (_isGif(bytes)) {
        return await _write(bytes, ExerciseMediaKind.gif, source: source);
      }
      final scale = descriptor.width > descriptor.height
          ? descriptor.width / 1600
          : descriptor.height / 1600;
      final codec = await descriptor.instantiateCodec(
        targetWidth: scale > 1
            ? (descriptor.width / scale).round()
            : descriptor.width,
        targetHeight: scale > 1
            ? (descriptor.height / scale).round()
            : descriptor.height,
      );
      try {
        final frame = await codec.getNextFrame();
        try {
          final data = await frame.image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (data == null) {
            throw const FormatException('Could not read this image.');
          }
          return await _write(
            data.buffer.asUint8List(),
            ExerciseMediaKind.image,
            source: source,
          );
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } finally {
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  /// Called only after the user taps Download on a curated guide.
  Future<List<ExerciseMedia>> downloadGuide(
    List<Uri> urls, {
    bool Function(String)? isReferenced,
  }) async {
    final client = _client ?? http.Client();
    final imported = <ExerciseMedia>[];
    try {
      for (final url in urls) {
        if (url.scheme != 'https' ||
            url.host != 'raw.githubusercontent.com' ||
            !url.path.startsWith('/yuhonas/free-exercise-db/')) {
          throw const FormatException('Unknown demonstration source.');
        }
        final response = await client
            .send(http.Request('GET', url)..followRedirects = false)
            .timeout(const Duration(seconds: 20));
        if (response.statusCode != 200 ||
            (response.contentLength ?? 0) > maxImageBytes) {
          throw const FormatException('Could not download the demonstration.');
        }
        final builder = BytesBuilder(copy: false);
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 20),
        )) {
          builder.add(chunk);
          if (builder.length > maxImageBytes) {
            throw const FormatException('Demonstration is too large.');
          }
        }
        imported.add(
          await importImage(builder.takeBytes(), source: 'free-exercise-db'),
        );
      }
      return imported;
    } catch (_) {
      if (isReferenced != null) {
        await discardUnreferenced(imported, isReferenced);
      }
      rethrow;
    } finally {
      if (_client == null) client.close();
    }
  }

  Future<ExerciseMedia> _write(
    Uint8List bytes,
    ExerciseMediaKind kind, {
    int? durationMs,
    String? source,
  }) async {
    final extension = switch (kind) {
      ExerciseMediaKind.image => 'png',
      ExerciseMediaKind.gif => 'gif',
      ExerciseMediaKind.video => 'mp4',
    };
    final media = ExerciseMedia(
      fileName: '${sha256.convert(bytes)}.$extension',
      kind: kind,
      durationMs: durationMs,
      source: source,
    );
    media.validate();
    _validateBytes(media, bytes);
    final destination = await fileFor(media);
    if (!await destination.exists()) {
      final temp = File(
        '${destination.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
      );
      try {
        await temp.writeAsBytes(bytes, flush: true);
        await temp.rename(destination.path);
      } finally {
        if (await temp.exists()) await temp.delete();
      }
    }
    return media;
  }

  /// Only candidates owned by the editor/download are removed. Re-check live
  /// references after filesystem awaits; shared content stays intact.
  Future<void> discardUnreferenced(
    Iterable<ExerciseMedia> candidates,
    bool Function(String) isReferenced,
  ) async {
    for (final media in candidates) {
      try {
        final file = await fileFor(media);
        if (await file.exists() && !isReferenced(media.fileName)) {
          await file.delete();
        }
      } on FileSystemException {
        /* A later edit can clean up a locked file. */
      }
    }
  }

  static bool _isGif(List<int> b) =>
      b.length >= 13 &&
      ascii.decode(b.sublist(0, 6), allowInvalid: true).startsWith('GIF8');
  static bool _isMp4(List<int> b) =>
      b.length >= 12 &&
      ascii.decode(b.sublist(4, 8), allowInvalid: true) == 'ftyp';
  static bool _isPng(List<int> b) =>
      b.length >= 33 &&
      b[0] == 137 &&
      b[1] == 80 &&
      b[2] == 78 &&
      b[3] == 71 &&
      b[4] == 13 &&
      b[5] == 10 &&
      b[6] == 26 &&
      b[7] == 10 &&
      ascii.decode(b.sublist(12, 16), allowInvalid: true) == 'IHDR';

  static void _validateBytes(ExerciseMedia m, List<int> bytes) {
    final limit = m.kind == ExerciseMediaKind.video
        ? maxVideoBytes
        : maxImageBytes;
    if (bytes.isEmpty ||
        bytes.length > limit ||
        !m.fileName.startsWith(sha256.convert(bytes).toString())) {
      throw const FormatException('Invalid or oversized media in backup.');
    }
    final valid = switch (m.kind) {
      ExerciseMediaKind.image => _isPng(bytes),
      ExerciseMediaKind.gif => _isGif(bytes),
      ExerciseMediaKind.video => _isMp4(bytes),
    };
    if (!valid) {
      throw const FormatException('Media content does not match its type.');
    }
    if (m.kind != ExerciseMediaKind.video) {
      final header = ByteData.sublistView(
        Uint8List.fromList(bytes.take(24).toList()),
      );
      final width = m.kind == ExerciseMediaKind.image
          ? header.getUint32(16)
          : header.getUint16(6, Endian.little);
      final height = m.kind == ExerciseMediaKind.image
          ? header.getUint32(20)
          : header.getUint16(8, Endian.little);
      if (width <= 0 || height <= 0 || width * height > 16000000) {
        throw const FormatException('Media image dimensions exceed the limit.');
      }
    }
  }

  static List<ExerciseMedia> references(Map<String, dynamic> data) => [
    for (final key in ['customExercises', 'exerciseOverrides'])
      for (final row in (data[key] as List? ?? const []))
        for (final item in ((row as Map)['media'] as List? ?? const []))
          ExerciseMedia.fromJson(Map<String, dynamic>.from(item as Map)),
  ];

  Future<String> encodeBackup(Map<String, dynamic> data) async {
    final refs = references(data);
    if (refs.isEmpty) return jsonEncode(data);
    final blobs = <String, String>{};
    var size = 0;
    for (final media in refs) {
      if (blobs.containsKey(media.fileName)) continue;
      final file = await fileFor(media);
      if (!await file.exists()) {
        throw const FormatException(
          'An exercise media file is missing. Remove or replace it before exporting.',
        );
      }
      final bytes = await file.readAsBytes();
      _validateBytes(media, bytes);
      size += bytes.length;
      if (size > maxBackupBytes) {
        throw const FormatException(
          'Media exceeds the 80 MB backup limit. Remove some media before exporting.',
        );
      }
      blobs[media.fileName] = base64Encode(bytes);
    }
    return jsonEncode({
      ...data,
      'backupFormatVersion': 2,
      'exerciseMedia': blobs,
    });
  }

  /// Validate ALL bytes before the database merge can begin. Hash names prevent
  /// imported files from overwriting a different local demonstration.
  static Map<String, Uint8List> validateBackup(Map<String, dynamic> data) {
    final refs = references(data);
    final payload = data['exerciseMedia'];
    if (refs.isEmpty && payload == null) return {};
    if (data['backupFormatVersion'] != 2 || payload is! Map<String, dynamic>) {
      throw const FormatException(
        'Exercise media is missing from this backup.',
      );
    }
    final blobs = <String, Uint8List>{};
    var size = 0;
    for (final media in refs) {
      if (blobs.containsKey(media.fileName)) continue;
      final encoded = payload[media.fileName];
      if (encoded is! String ||
          encoded.length > (maxVideoBytes * 4 / 3).ceil() + 4) {
        throw const FormatException('Invalid exercise media backup.');
      }
      final bytes = base64Decode(encoded);
      _validateBytes(media, bytes);
      size += bytes.length;
      if (size > maxBackupBytes) {
        throw const FormatException('Media backup exceeds 80 MB.');
      }
      blobs[media.fileName] = bytes;
    }
    if (payload.length != blobs.length) {
      throw const FormatException('Unreferenced media in backup.');
    }
    return blobs;
  }

  Future<void> restoreBackup(Map<String, dynamic> data) async {
    final blobs = validateBackup(data);
    if (blobs.isEmpty) return;
    for (final media in references(data)) {
      final bytes = blobs.remove(media.fileName);
      if (bytes != null) {
        await _write(
          bytes,
          media.kind,
          durationMs: media.durationMs,
          source: media.source,
        );
      }
    }
  }
}
