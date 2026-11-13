/// Lossless fields needed to import a Health Connect exercise session.
class HealthConnectWorkout {
  const HealthConnectWorkout({
    required this.recordId,
    required this.origin,
    required this.start,
    required this.end,
    required this.segments,
    this.clientRecordId,
    this.version = 0,
    this.title,
    this.notes,
    this.exerciseType,
    this.modifiedAt,
  });
  final String recordId;
  final String origin;
  final String? clientRecordId;
  final int version;
  final DateTime start;
  final DateTime end;
  final String? title;
  final String? notes;
  final String? exerciseType;
  final DateTime? modifiedAt;
  final List<HealthConnectWorkoutSegment> segments;
  Map<String, dynamic> toJson() => {
    'recordId': recordId,
    'origin': origin,
    'clientRecordId': clientRecordId,
    'version': version,
    'start': start.toUtc().toIso8601String(),
    'end': end.toUtc().toIso8601String(),
    'title': title,
    'notes': notes,
    if (exerciseType != null) 'exerciseType': exerciseType,
    if (modifiedAt != null) 'modifiedAt': modifiedAt!.toUtc().toIso8601String(),
    'segments': [for (final segment in segments) segment.toJson()],
  };
}

class HealthConnectWorkoutSegment {
  const HealthConnectWorkoutSegment({
    required this.start,
    required this.end,
    required this.isRest,
    this.repetitions,
    this.weightKg,
    this.exerciseId,
    this.segmentType,
  });
  final DateTime start;
  final DateTime end;
  final bool isRest;
  final int? repetitions;
  final double? weightKg;
  final String? exerciseId;
  final String? segmentType;
  Map<String, dynamic> toJson() => {
    'start': start.toUtc().toIso8601String(),
    'end': end.toUtc().toIso8601String(),
    'isRest': isRest,
    'repetitions': repetitions,
    'weightKg': weightKg,
    if (exerciseId != null) 'exerciseId': exerciseId,
    if (segmentType != null) 'segmentType': segmentType,
  };
}
