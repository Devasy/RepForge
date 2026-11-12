import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/exercise_database.dart';
import '../data/fitify_muscle_data.dart';
import '../models/models.dart';

class MuscleIntensityProfile {
  const MuscleIntensityProfile({
    required this.code,
    required this.name,
    required this.resistance,
    required this.stretch,
    required this.exerciseType,
    required this.sourceVersion,
    String? resistanceAttribution,
    String? stretchAttribution,
  }) : _resistanceAttribution = resistanceAttribution,
       _stretchAttribution = stretchAttribution;

  final String code;
  final String name;
  final Map<String, num> resistance;
  final Map<String, num> stretch;
  final ExerciseType exerciseType;
  final String sourceVersion;
  final String? _resistanceAttribution;
  final String? _stretchAttribution;
  String get resistanceAttribution =>
      _resistanceAttribution ?? 'Fitify · $sourceVersion';
  String get stretchAttribution =>
      _stretchAttribution ?? 'Fitify · $sourceVersion';

  String? get primaryMuscle {
    final scores = resistance.isNotEmpty ? resistance : stretch;
    if (scores.isEmpty) return null;
    return scores.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  bool matchesMuscle(String id) {
    final scores = {...resistance, ...stretch};
    final ids = switch (id) {
      'core' => ['abs', 'obliques'],
      'forearms' => ['forearm_anterior', 'forearm_posterior'],
      'shoulders' => ['front_delts', 'side_delts', 'rear_delts'],
      _ => [id],
    };
    return ids.any(scores.containsKey);
  }

  static MuscleIntensityProfile parse(
    Map<String, dynamic> row,
    String version,
  ) {
    final code = row['code'];
    final name = row['name'];
    if (code is! String ||
        !RegExp(r'^[a-z0-9_]{1,160}$').hasMatch(code) ||
        name is! String ||
        name.trim().isEmpty ||
        name.length > 200) {
      throw const FormatException('Invalid exercise identity.');
    }
    final type = switch (row['exerciseType']) {
      'weightAndReps' => ExerciseType.weightAndReps,
      'timeBased' => ExerciseType.timeBased,
      _ => throw const FormatException('Invalid exercise tracking type.'),
    };
    return MuscleIntensityProfile(
      code: code,
      name: name.trim(),
      resistance: _scores(row['resistance']),
      stretch: _scores(row['stretch']),
      exerciseType: type,
      sourceVersion: version,
    );
  }

  static Map<String, int> _scores(dynamic value) {
    if (value is! Map) throw const FormatException('Missing muscle scores.');
    final scores = <String, int>{};
    for (final entry in value.entries) {
      final score = entry.value;
      if (!MuscleGroups.names.containsKey(entry.key) ||
          score is! int ||
          score < 1 ||
          score > 10) {
        throw const FormatException(
          'Muscle scores must use known muscles and integers from 1 to 10.',
        );
      }
      scores[entry.key as String] = score;
    }
    return Map.unmodifiable(scores);
  }

  Exercise toExercise() => Exercise(
    id: 'fitify:$code',
    name: name,
    category: 'other',
    exerciseType: exerciseType,
    // Relative involvement weights, not measured activation percentages.
    muscleActivations: [
      for (final entry in resistance.entries)
        MuscleActivation(
          muscleGroupId: entry.key,
          activationPercentage: (entry.value * 10).round(),
        ),
    ],
  );
}

final _builtInProfiles = Map<String, MuscleIntensityProfile>.unmodifiable({
  for (final entry in fitifyBuiltInProfiles.entries)
    entry.key: MuscleIntensityProfile.parse(
      Map<String, dynamic>.from(entry.value),
      '1.136.0',
    ),
});

class ExtendedExerciseLibrary {
  ExtendedExerciseLibrary._(this.profiles);

  static const settingKey = 'exerciseLibrary.fitify.v1';
  static const maxBytes = 1024 * 1024;
  static final downloadUri = Uri.parse(
    'https://raw.githubusercontent.com/Devasy/RepForge/r2.2.3/catalogues/fitify-v1.json',
  );
  final Map<String, MuscleIntensityProfile> profiles;
  int get length => profiles.length;

  static MuscleIntensityProfile? builtInProfileFor(String id) =>
      _builtInProfiles[id];

  factory ExtendedExerciseLibrary.fromJson(String text) {
    if (utf8.encode(text).length > maxBytes) {
      throw const FormatException('Exercise library is too large.');
    }
    final data = jsonDecode(text);
    if (data is! Map ||
        data['schema'] != 'repforge.exercise_library' ||
        data['version'] != 1) {
      throw const FormatException('Unsupported exercise library format.');
    }
    final source = data['source'];
    if (source is! Map ||
        source['name'] != 'Fitify' ||
        source['appVersion'] is! String) {
      throw const FormatException('Missing exercise library source.');
    }
    final entries = data['exercises'];
    if (entries is! List || entries.isEmpty || entries.length > 3000) {
      throw const FormatException('Invalid exercise library entries.');
    }
    final profiles = <String, MuscleIntensityProfile>{};
    for (final entry in entries) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('Invalid exercise entry.');
      }
      final profile = MuscleIntensityProfile.parse(
        entry,
        source['appVersion'] as String,
      );
      if (profiles.containsKey(profile.code)) {
        throw const FormatException('Duplicate exercise code.');
      }
      profiles[profile.code] = profile;
    }
    return ExtendedExerciseLibrary._(Map.unmodifiable(profiles));
  }

  static ExtendedExerciseLibrary? fromCache(String? text) {
    if (text == null) return null;
    try {
      return ExtendedExerciseLibrary.fromJson(text);
    } on FormatException {
      return null;
    }
  }

  MuscleIntensityProfile? profileFor(String id) {
    final code = id.startsWith('fitify:')
        ? id.substring(7)
        : _builtInProfiles[id]?.code;
    return profiles[code] ?? _builtInProfiles[id];
  }

  List<Exercise> mergeExercises(List<Exercise> existing) {
    final result = <String, Exercise>{
      for (final exercise in existing) exercise.id: exercise,
    };
    final mappedCodes = {
      for (final entry in _builtInProfiles.entries)
        if (result.containsKey(entry.key)) entry.value.code,
    };
    for (final profile in profiles.values) {
      if (!mappedCodes.contains(profile.code)) {
        final exercise = profile.toExercise();
        result.putIfAbsent(exercise.id, () => exercise);
      }
    }
    return result.values.toList();
  }

  static Future<String> download({http.Client? client}) async {
    final connection = client ?? http.Client();
    try {
      return await (() async {
        final response = await connection.send(
          http.Request('GET', downloadUri),
        );
        if (response.statusCode != 200) {
          throw StateError(
            'Exercise library download failed (${response.statusCode}).',
          );
        }
        if ((response.contentLength ?? 0) > maxBytes) {
          throw const FormatException('Exercise library is too large.');
        }
        final bytes = <int>[];
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > maxBytes) {
            throw const FormatException('Exercise library is too large.');
          }
          bytes.addAll(chunk);
        }
        final text = utf8.decode(bytes);
        ExtendedExerciseLibrary.fromJson(text);
        return text;
      })().timeout(const Duration(seconds: 20));
    } finally {
      if (client == null) connection.close();
    }
  }
}
