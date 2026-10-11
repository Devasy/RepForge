enum ExerciseMediaKind { image, gif, video }

/// Content-addressed app-private file. Absolute paths never enter the database.
class ExerciseMedia {
  final String fileName;
  final ExerciseMediaKind kind;
  final int? durationMs;
  final String? source;

  const ExerciseMedia({
    required this.fileName,
    required this.kind,
    this.durationMs,
    this.source,
  });

  static final _name = RegExp(r'^[a-f0-9]{64}\.(png|gif|mp4)$');
  void validate() {
    final extension = switch (kind) {
      ExerciseMediaKind.image => 'png',
      ExerciseMediaKind.gif => 'gif',
      ExerciseMediaKind.video => 'mp4',
    };
    if (!_name.hasMatch(fileName) || !fileName.endsWith('.$extension')) {
      throw const FormatException('Invalid exercise media reference.');
    }
    if (kind == ExerciseMediaKind.video &&
        (durationMs == null || durationMs! <= 0 || durationMs! > 60000)) {
      throw const FormatException('Videos must be at most 60 seconds.');
    }
    if (source != null && source != 'free-exercise-db') {
      throw const FormatException('Unknown exercise media source.');
    }
  }

  Map<String, dynamic> toJson() => {
    'fileName': fileName,
    'kind': kind.name,
    if (durationMs != null) 'durationMs': durationMs,
    if (source != null) 'source': source,
  };

  factory ExerciseMedia.fromJson(Map<String, dynamic> json) {
    final media = ExerciseMedia(
      fileName: json['fileName'] as String,
      kind: ExerciseMediaKind.values.firstWhere((v) => v.name == json['kind']),
      durationMs: json['durationMs'] as int?,
      source: json['source'] as String?,
    );
    media.validate();
    return media;
  }
}
