// Data Models for Workout Logger App

import 'dart:math' show log, max;

import 'package:uuid/uuid.dart';

// Sentinel value for copyWith methods to distinguish "not provided" from "null"
const Object _sentinel = Object();

const _uuid = Uuid();

// ==================== Muscle Groups ====================

class MuscleGroup {
  final String id;
  final String name;
  double growthRate; // Learned coefficient (volume increase per session)
  DateTime lastUpdated;

  MuscleGroup({
    required this.id,
    required this.name,
    this.growthRate = 0.0,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'growthRate': growthRate,
    'lastUpdated': lastUpdated.toIso8601String(),
  };

  factory MuscleGroup.fromJson(Map<String, dynamic> json) => MuscleGroup(
    id: json['id'],
    name: json['name'],
    growthRate: (json['growthRate'] as num?)?.toDouble() ?? 0.0,
    lastUpdated: DateTime.parse(json['lastUpdated']),
  );
}

// ==================== Muscle Activation ====================

class MuscleActivation {
  final String muscleGroupId;
  final int activationPercentage; // 0-100

  MuscleActivation({
    required this.muscleGroupId,
    required this.activationPercentage,
  });

  Map<String, dynamic> toJson() => {
    'muscleGroupId': muscleGroupId,
    'activationPercentage': activationPercentage,
  };

  factory MuscleActivation.fromJson(Map<String, dynamic> json) =>
      MuscleActivation(
        muscleGroupId: json['muscleGroupId'],
        activationPercentage: json['activationPercentage'],
      );
}

// ==================== Exercise ====================

// Exercise IDs treated as bodyweight-assisted (e.g. an assisted-dip/pull-up
// machine). Computed once here so every consumer (the load panel, the input
// row, set persistence) agrees on which exercises count as "assisted".
const Set<String> _assistedBodyweightExerciseIds = {
  'pull_ups',
  'chin_ups',
  'dips',
  'push_ups',
};

bool isAssistedBodyweightExercise(String? exerciseId) =>
    exerciseId != null && _assistedBodyweightExerciseIds.contains(exerciseId);

class Exercise {
  final String id;
  final String name;
  final List<MuscleActivation> muscleActivations;
  final String category; // 'compound' or 'isolation'
  final bool isCustom; // User-created exercise
  final List<String>? availableHandles; // Attachment/handle options e.g. ['Rope', 'Bar']

  const Exercise({
    required this.id,
    required this.name,
    required this.muscleActivations,
    required this.category,
    this.isCustom = false,
    this.availableHandles,
  });

  String get primaryMuscle {
    if (muscleActivations.isEmpty) return 'Unknown';
    final sorted = List<MuscleActivation>.from(
      muscleActivations,
    )..sort((a, b) => b.activationPercentage.compareTo(a.activationPercentage));
    return sorted.first.muscleGroupId;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'muscleActivations': muscleActivations.map((m) => m.toJson()).toList(),
    'category': category,
    'isCustom': isCustom,
    'availableHandles': availableHandles,
  };

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
    id: json['id'],
    name: json['name'],
    muscleActivations: (json['muscleActivations'] as List)
        .map((m) => MuscleActivation.fromJson(m))
        .toList(),
    category: json['category'],
    isCustom: json['isCustom'] ?? false,
    availableHandles: (json['availableHandles'] as List?)?.cast<String>(),
  );
}

// ==================== Workout Set ====================

class WorkoutSet {
  final double weight; // in kg
  final int reps;
  final bool isDropset;
  final List<DropsetEntry>? drops; // For dropsets
  final int? timeTaken; // seconds
  final DateTime timestamp;
  final double? assistWeight;
  final double? extraWeight;
  final String? handle;
  final double? bodyWeightAtLog;

  WorkoutSet({
    required this.weight,
    required this.reps,
    this.isDropset = false,
    this.drops,
    this.timeTaken,
    DateTime? timestamp,
    this.assistWeight,
    this.extraWeight,
    this.handle,
    this.bodyWeightAtLog,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Per-rep effective load for the main (non-drop) entry of this set: for
  /// assisted-bodyweight sets (i.e. [assistWeight] is set) this is
  /// `bodyweight − assist + extra`, snapshotted against [bodyWeightAtLog]
  /// (falling back to 70.0) so historical values stay correct even if the
  /// user's current bodyweight later changes. Conventional (non-assisted)
  /// sets just use [weight]. Use this (not raw [weight]) wherever a
  /// "how heavy was this set" comparison needs to be consistent with
  /// [calculateVolume] for assisted-bodyweight exercises.
  double get effectiveWeight {
    final assist = assistWeight;
    if (assist == null) return weight;
    final bw = bodyWeightAtLog ?? 70.0;
    return max(0.0, bw - assist + (extraWeight ?? 0.0));
  }

  double calculateVolume({double? userBodyWeight, bool? isAssistedBW}) {
    final assisted = isAssistedBW ?? (assistWeight != null);
    final bw = bodyWeightAtLog ?? userBodyWeight ?? 70.0;
    final effW = assisted
        ? max(0.0, bw - (assistWeight ?? weight) + (extraWeight ?? 0.0))
        : weight;
    double vol = effW * reps;
    if (isDropset && drops != null) {
      for (final drop in drops!) {
        final dropEff = assisted
            ? max(0.0, bw - drop.weight + (extraWeight ?? 0.0))
            : drop.weight;
        vol += dropEff * drop.reps;
      }
    }
    return vol;
  }

  double get volume => calculateVolume();

  Map<String, dynamic> toJson() => {
    'weight': weight,
    'reps': reps,
    'isDropset': isDropset,
    'drops': drops?.map((d) => d.toJson()).toList(),
    'timeTaken': timeTaken,
    'timestamp': timestamp.toIso8601String(),
    'assistWeight': assistWeight,
    'extraWeight': extraWeight,
    'handle': handle,
    'bodyWeightAtLog': bodyWeightAtLog,
  };

  factory WorkoutSet.fromJson(Map<String, dynamic> json) => WorkoutSet(
    weight: (json['weight'] as num).toDouble(),
    reps: json['reps'],
    isDropset: json['isDropset'] ?? false,
    drops: json['drops'] != null
        ? (json['drops'] as List).map((d) => DropsetEntry.fromJson(d)).toList()
        : null,
    timeTaken: json['timeTaken'],
    timestamp: DateTime.parse(json['timestamp']),
    assistWeight: (json['assistWeight'] as num?)?.toDouble(),
    extraWeight: (json['extraWeight'] as num?)?.toDouble(),
    handle: json['handle'] as String?,
    bodyWeightAtLog: (json['bodyWeightAtLog'] as num?)?.toDouble(),
  );

  WorkoutSet copyWith({
    Object? weight = _sentinel,
    Object? reps = _sentinel,
    Object? isDropset = _sentinel,
    Object? drops = _sentinel,
    Object? timeTaken = _sentinel,
    Object? timestamp = _sentinel,
    Object? assistWeight = _sentinel,
    Object? extraWeight = _sentinel,
    Object? handle = _sentinel,
    Object? bodyWeightAtLog = _sentinel,
  }) => WorkoutSet(
    weight: weight == _sentinel ? this.weight : weight as double,
    reps: reps == _sentinel ? this.reps : reps as int,
    isDropset: isDropset == _sentinel ? this.isDropset : isDropset as bool,
    drops: drops == _sentinel ? this.drops : drops as List<DropsetEntry>?,
    timeTaken: timeTaken == _sentinel ? this.timeTaken : timeTaken as int?,
    timestamp: timestamp == _sentinel ? this.timestamp : timestamp as DateTime?,
    assistWeight: assistWeight == _sentinel ? this.assistWeight : assistWeight as double?,
    extraWeight: extraWeight == _sentinel ? this.extraWeight : extraWeight as double?,
    handle: handle == _sentinel ? this.handle : handle as String?,
    bodyWeightAtLog: bodyWeightAtLog == _sentinel ? this.bodyWeightAtLog : bodyWeightAtLog as double?,
  );
}

class DropsetEntry {
  final String id;
  final double weight;
  final int reps;

  DropsetEntry({String? id, required this.weight, required this.reps})
      : id = id ?? _uuid.v4();

  Map<String, dynamic> toJson() => {'id': id, 'weight': weight, 'reps': reps};

  factory DropsetEntry.fromJson(Map<String, dynamic> json) => DropsetEntry(
    id: json['id'] as String?,
    weight: (json['weight'] as num).toDouble(),
    reps: json['reps'],
  );
}

// ==================== Exercise Log ====================

class ExerciseLog {
  final String exerciseId;
  final List<WorkoutSet> sets;
  final String? notes;
  final String? handle;

  const ExerciseLog({
    required this.exerciseId,
    required this.sets,
    this.notes,
    this.handle,
  });

  double calculateTotalVolume({double? userBodyWeight, bool? isAssistedBW}) =>
      sets.fold(0.0, (sum, set) => sum + set.calculateVolume(userBodyWeight: userBodyWeight, isAssistedBW: isAssistedBW));

  double get totalVolume => sets.fold(0.0, (sum, set) => sum + set.volume);

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'sets': sets.map((s) => s.toJson()).toList(),
    'notes': notes,
    'handle': handle,
  };

  factory ExerciseLog.fromJson(Map<String, dynamic> json) => ExerciseLog(
    exerciseId: json['exerciseId'],
    sets: (json['sets'] as List).map((s) => WorkoutSet.fromJson(s)).toList(),
    notes: json['notes'],
    handle: json['handle'] as String?,
  );

  ExerciseLog copyWith({
    Object? exerciseId = _sentinel,
    Object? sets = _sentinel,
    Object? notes = _sentinel,
    Object? handle = _sentinel,
  }) => ExerciseLog(
    exerciseId: exerciseId == _sentinel
        ? this.exerciseId
        : exerciseId as String,
    sets: sets == _sentinel ? this.sets : sets as List<WorkoutSet>,
    notes: notes == _sentinel ? this.notes : notes as String?,
    handle: handle == _sentinel ? this.handle : handle as String?,
  );
}

// ==================== Workout Session ====================

class WorkoutSession {
  final String id;
  final DateTime date;
  final String? routineId;
  final List<ExerciseLog> exercises;
  final int duration; // minutes
  final String? notes;
  /// Non-null when this session was successfully synced to Health Connect.
  final DateTime? hcSyncedAt;

  WorkoutSession({
    required this.id,
    required this.date,
    this.routineId,
    required this.exercises,
    required this.duration,
    this.notes,
    this.hcSyncedAt,
  });

  double get totalVolume =>
      exercises.fold(0.0, (sum, ex) => sum + ex.totalVolume);

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'routineId': routineId,
    'exercises': exercises.map((e) => e.toJson()).toList(),
    'duration': duration,
    'notes': notes,
    'hcSyncedAt': hcSyncedAt?.toIso8601String(),
  };

  factory WorkoutSession.fromJson(Map<String, dynamic> json) => WorkoutSession(
    id: json['id'],
    date: DateTime.parse(json['date']),
    routineId: json['routineId'],
    exercises: (json['exercises'] as List)
        .map((e) => ExerciseLog.fromJson(e))
        .toList(),
    duration: json['duration'],
    notes: json['notes'],
    hcSyncedAt: json['hcSyncedAt'] != null
        ? DateTime.parse(json['hcSyncedAt'] as String)
        : null,
  );

  WorkoutSession copyWith({
    Object? id = _sentinel,
    Object? date = _sentinel,
    Object? routineId = _sentinel,
    Object? exercises = _sentinel,
    Object? duration = _sentinel,
    Object? notes = _sentinel,
    Object? hcSyncedAt = _sentinel,
  }) => WorkoutSession(
    id: id == _sentinel ? this.id : id as String,
    date: date == _sentinel ? this.date : date as DateTime,
    routineId: routineId == _sentinel ? this.routineId : routineId as String?,
    exercises: exercises == _sentinel
        ? this.exercises
        : exercises as List<ExerciseLog>,
    duration: duration == _sentinel ? this.duration : duration as int,
    notes: notes == _sentinel ? this.notes : notes as String?,
    hcSyncedAt: hcSyncedAt == _sentinel
        ? this.hcSyncedAt
        : hcSyncedAt as DateTime?,
  );
}

// ==================== Routine ====================

class Routine {
  final String id;
  final String name;
  final List<String> exerciseIds;
  final DateTime createdAt;

  Routine({
    required this.id,
    required this.name,
    required this.exerciseIds,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'exerciseIds': exerciseIds,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Routine.fromJson(Map<String, dynamic> json) => Routine(
    id: json['id'],
    name: json['name'],
    exerciseIds: List<String>.from(json['exerciseIds']),
    createdAt: DateTime.parse(json['createdAt']),
  );

  Routine copyWith({String? name, List<String>? exerciseIds}) => Routine(
    id: id,
    name: name ?? this.name,
    exerciseIds: exerciseIds ?? this.exerciseIds,
    createdAt: createdAt,
  );
}

// ==================== Target ====================

class Target {
  final String id;
  final String exerciseId;
  final String targetType; // 'reps', 'weight', 'volume'
  final double targetValue;
  double currentValue;
  DateTime? estimatedCompletionDate;
  final DateTime createdAt;
  bool isCompleted;

  Target({
    required this.id,
    required this.exerciseId,
    required this.targetType,
    required this.targetValue,
    this.currentValue = 0.0,
    this.estimatedCompletionDate,
    DateTime? createdAt,
    this.isCompleted = false,
  }) : createdAt = createdAt ?? DateTime.now();

  double get progressPercentage =>
      (currentValue / targetValue * 100).clamp(0, 100);

  Map<String, dynamic> toJson() => {
    'id': id,
    'exerciseId': exerciseId,
    'targetType': targetType,
    'targetValue': targetValue,
    'currentValue': currentValue,
    'estimatedCompletionDate': estimatedCompletionDate?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'isCompleted': isCompleted,
  };

  factory Target.fromJson(Map<String, dynamic> json) => Target(
    id: json['id'],
    exerciseId: json['exerciseId'],
    targetType: json['targetType'],
    targetValue: (json['targetValue'] as num).toDouble(),
    currentValue: (json['currentValue'] as num?)?.toDouble() ?? 0.0,
    estimatedCompletionDate: json['estimatedCompletionDate'] != null
        ? DateTime.parse(json['estimatedCompletionDate'])
        : null,
    createdAt: DateTime.parse(json['createdAt']),
    isCompleted: json['isCompleted'] ?? false,
  );
}

// ==================== Set Recommendation ====================

class SetRecommendation {
  final double weight;
  final int reps;
  final String confidence; // 'high', 'medium', 'low'
  final String reasoning;

  SetRecommendation({
    required this.weight,
    required this.reps,
    required this.confidence,
    required this.reasoning,
  });
}

// ==================== Growth Model ====================

/// Functional form of a fitted growth curve.
///
/// - [linear]: steady volume gains (typical for newer lifters / new exercises)
/// - [logarithmic]: diminishing returns, y = a + b·ln(1+x) — typical as an
///   exercise matures and progress saturates
enum GrowthCurve { linear, logarithmic }

class GrowthModel {
  /// Instantaneous growth rate (volume per day) at the most recent data point.
  /// For linear fits this equals the curve coefficient; for logarithmic fits
  /// it is the tangent slope b/(1+lastX), which decays as training history grows.
  final double slope;
  final double intercept; // Curve intercept a
  final double r2; // Model fit quality (0-1)
  final DateTime lastTrained;
  final GrowthCurve curve;

  /// Curve coefficient b. Equals [slope] for linear fits.
  final double coefficient;

  /// x (days since first session) of the newest point used in training.
  final double lastX;

  /// Weighted residual standard error in volume units (0 = unknown/perfect).
  final double stdError;

  GrowthModel({
    required this.slope,
    required this.intercept,
    required this.r2,
    required this.lastTrained,
    this.curve = GrowthCurve.linear,
    double? coefficient,
    this.lastX = 0,
    this.stdError = 0,
  }) : coefficient = coefficient ?? slope;

  double predict(num x) {
    switch (curve) {
      case GrowthCurve.linear:
        return intercept + coefficient * x;
      case GrowthCurve.logarithmic:
        return intercept + coefficient * log(1 + max(0, x.toDouble()));
    }
  }

  /// Model's volume estimate at the newest training point ("today's level").
  double get currentEstimate => predict(lastX);

  /// Expected volume growth over the next 7 days as a percentage of the
  /// current level. The plateau/decline signal used by recommendations.
  double get weeklyGrowthPercent {
    final current = currentEstimate;
    if (current <= 0) return 0;
    return slope * 7 / current * 100;
  }
}

// ==================== Personal Record ====================

class PersonalRecord {
  final String exerciseId;
  final double bestWeight; // heaviest weight in any single set
  final int bestReps;      // most reps in any single set
  final double bestVolume; // highest single-set volume (weight × reps)
  final DateTime achievedAt;

  PersonalRecord({
    required this.exerciseId,
    required this.bestWeight,
    required this.bestReps,
    required this.bestVolume,
    required this.achievedAt,
  });

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'bestWeight': bestWeight,
    'bestReps': bestReps,
    'bestVolume': bestVolume,
    'achievedAt': achievedAt.toIso8601String(),
  };

  factory PersonalRecord.fromJson(Map<String, dynamic> json) => PersonalRecord(
    exerciseId: json['exerciseId'] as String,
    bestWeight: (json['bestWeight'] as num).toDouble(),
    bestReps: json['bestReps'] as int,
    bestVolume: (json['bestVolume'] as num).toDouble(),
    achievedAt: DateTime.parse(json['achievedAt'] as String),
  );

  PersonalRecord copyWith({
    double? bestWeight,
    int? bestReps,
    double? bestVolume,
    DateTime? achievedAt,
  }) => PersonalRecord(
    exerciseId: exerciseId,
    bestWeight: bestWeight ?? this.bestWeight,
    bestReps: bestReps ?? this.bestReps,
    bestVolume: bestVolume ?? this.bestVolume,
    achievedAt: achievedAt ?? this.achievedAt,
  );
}

// ==================== Training Program ====================

/// One exercise slot inside a program day.
///
/// Holds all programming parameters: sets, rep range, rest, tempo, weight%, notes,
/// and an optional superset group ID to visually link paired/grouped exercises.
class ProgramExerciseSlot {
  final String exerciseId;
  final int sets;
  final int minReps;
  final int maxReps;
  final int restSeconds;
  final String? tempo; // e.g. "3-1-1" (eccentric-pause-concentric)
  final double? weightPercentage; // % of working weight / 1RM hint
  final String? notes;
  final String? supersetGroupId; // non-null → belongs to a superset

  ProgramExerciseSlot({
    required this.exerciseId,
    required this.sets,
    required this.minReps,
    required this.maxReps,
    required this.restSeconds,
    this.tempo,
    this.weightPercentage,
    this.notes,
    this.supersetGroupId,
  });

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'sets': sets,
    'minReps': minReps,
    'maxReps': maxReps,
    'restSeconds': restSeconds,
    'tempo': tempo,
    'weightPercentage': weightPercentage,
    'notes': notes,
    'supersetGroupId': supersetGroupId,
  };

  factory ProgramExerciseSlot.fromJson(Map<String, dynamic> json) =>
      ProgramExerciseSlot(
        exerciseId: json['exerciseId'] as String,
        sets: json['sets'] as int,
        minReps: json['minReps'] as int,
        maxReps: json['maxReps'] as int,
        restSeconds: json['restSeconds'] as int,
        tempo: json['tempo'] as String?,
        weightPercentage: (json['weightPercentage'] as num?)?.toDouble(),
        notes: json['notes'] as String?,
        supersetGroupId: json['supersetGroupId'] as String?,
      );

  ProgramExerciseSlot copyWith({
    Object? exerciseId = _sentinel,
    Object? sets = _sentinel,
    Object? minReps = _sentinel,
    Object? maxReps = _sentinel,
    Object? restSeconds = _sentinel,
    Object? tempo = _sentinel,
    Object? weightPercentage = _sentinel,
    Object? notes = _sentinel,
    Object? supersetGroupId = _sentinel,
  }) => ProgramExerciseSlot(
    exerciseId:
        exerciseId == _sentinel ? this.exerciseId : exerciseId as String,
    sets: sets == _sentinel ? this.sets : sets as int,
    minReps: minReps == _sentinel ? this.minReps : minReps as int,
    maxReps: maxReps == _sentinel ? this.maxReps : maxReps as int,
    restSeconds:
        restSeconds == _sentinel ? this.restSeconds : restSeconds as int,
    tempo: tempo == _sentinel ? this.tempo : tempo as String?,
    weightPercentage: weightPercentage == _sentinel
        ? this.weightPercentage
        : weightPercentage as double?,
    notes: notes == _sentinel ? this.notes : notes as String?,
    supersetGroupId: supersetGroupId == _sentinel
        ? this.supersetGroupId
        : supersetGroupId as String?,
  );
}

/// One training day inside a program week.
class ProgramDay {
  final String id;
  final String name; // e.g. "Push", "Pull", "Legs", "Core"
  final int? dayOfWeek; // 1=Mon … 7=Sun; null = unscheduled
  final String? notes;
  final List<ProgramExerciseSlot> exercises;

  ProgramDay({
    required this.id,
    required this.name,
    this.dayOfWeek,
    this.notes,
    required this.exercises,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'dayOfWeek': dayOfWeek,
    'notes': notes,
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };

  factory ProgramDay.fromJson(Map<String, dynamic> json) => ProgramDay(
    id: json['id'] as String,
    name: json['name'] as String,
    dayOfWeek: json['dayOfWeek'] as int?,
    notes: json['notes'] as String?,
    exercises: (json['exercises'] as List)
        .map((e) => ProgramExerciseSlot.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  ProgramDay copyWith({
    Object? id = _sentinel,
    Object? name = _sentinel,
    Object? dayOfWeek = _sentinel,
    Object? notes = _sentinel,
    Object? exercises = _sentinel,
  }) => ProgramDay(
    id: id == _sentinel ? this.id : id as String,
    name: name == _sentinel ? this.name : name as String,
    dayOfWeek: dayOfWeek == _sentinel ? this.dayOfWeek : dayOfWeek as int?,
    notes: notes == _sentinel ? this.notes : notes as String?,
    exercises: exercises == _sentinel
        ? this.exercises
        : exercises as List<ProgramExerciseSlot>,
  );
}

/// One week of a training program.
///
/// A deload week lowers volume/intensity to facilitate recovery.
/// [deloadIntensityFactor] of 0.85 means 85% of normal weight.
/// [deloadSetReduction] removes N sets per exercise (e.g. 1 or 2).
class ProgramWeek {
  final int weekNumber; // 1-based
  final bool isDeload;
  final double deloadIntensityFactor; // 0.0–1.0; default 1.0 (no change)
  final int deloadSetReduction; // sets removed per exercise on deload
  final String? phaseId;
  final String? notes;
  final List<ProgramDay> days;

  ProgramWeek({
    required this.weekNumber,
    this.isDeload = false,
    this.deloadIntensityFactor = 1.0,
    this.deloadSetReduction = 0,
    this.phaseId,
    this.notes,
    required this.days,
  });

  Map<String, dynamic> toJson() => {
    'weekNumber': weekNumber,
    'isDeload': isDeload,
    'deloadIntensityFactor': deloadIntensityFactor,
    'deloadSetReduction': deloadSetReduction,
    'phaseId': phaseId,
    'notes': notes,
    'days': days.map((d) => d.toJson()).toList(),
  };

  factory ProgramWeek.fromJson(Map<String, dynamic> json) => ProgramWeek(
    weekNumber: json['weekNumber'] as int,
    isDeload: json['isDeload'] as bool? ?? false,
    deloadIntensityFactor:
        (json['deloadIntensityFactor'] as num?)?.toDouble() ?? 1.0,
    deloadSetReduction: json['deloadSetReduction'] as int? ?? 0,
    phaseId: json['phaseId'] as String?,
    notes: json['notes'] as String?,
    days: (json['days'] as List)
        .map((d) => ProgramDay.fromJson(d as Map<String, dynamic>))
        .toList(),
  );

  ProgramWeek copyWith({
    Object? weekNumber = _sentinel,
    Object? isDeload = _sentinel,
    Object? deloadIntensityFactor = _sentinel,
    Object? deloadSetReduction = _sentinel,
    Object? phaseId = _sentinel,
    Object? notes = _sentinel,
    Object? days = _sentinel,
  }) => ProgramWeek(
    weekNumber: weekNumber == _sentinel ? this.weekNumber : weekNumber as int,
    isDeload: isDeload == _sentinel ? this.isDeload : isDeload as bool,
    deloadIntensityFactor: deloadIntensityFactor == _sentinel
        ? this.deloadIntensityFactor
        : deloadIntensityFactor as double,
    deloadSetReduction: deloadSetReduction == _sentinel
        ? this.deloadSetReduction
        : deloadSetReduction as int,
    phaseId: phaseId == _sentinel ? this.phaseId : phaseId as String?,
    notes: notes == _sentinel ? this.notes : notes as String?,
    days: days == _sentinel ? this.days : days as List<ProgramDay>,
  );
}

/// Named training phase (e.g. "Foundation", "Intensify", "Peak").
class TrainingPhase {
  final String id;
  final String name;
  final int startWeek; // 1-based, inclusive
  final int endWeek; // 1-based, inclusive
  final String? notes;
  final String? colorHex; // optional override for UI

  TrainingPhase({
    required this.id,
    required this.name,
    required this.startWeek,
    required this.endWeek,
    this.notes,
    this.colorHex,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'startWeek': startWeek,
    'endWeek': endWeek,
    'notes': notes,
    'colorHex': colorHex,
  };

  factory TrainingPhase.fromJson(Map<String, dynamic> json) => TrainingPhase(
    id: json['id'] as String,
    name: json['name'] as String,
    startWeek: json['startWeek'] as int,
    endWeek: json['endWeek'] as int,
    notes: json['notes'] as String?,
    colorHex: json['colorHex'] as String?,
  );

  TrainingPhase copyWith({
    Object? id = _sentinel,
    Object? name = _sentinel,
    Object? startWeek = _sentinel,
    Object? endWeek = _sentinel,
    Object? notes = _sentinel,
    Object? colorHex = _sentinel,
  }) => TrainingPhase(
    id: id == _sentinel ? this.id : id as String,
    name: name == _sentinel ? this.name : name as String,
    startWeek: startWeek == _sentinel ? this.startWeek : startWeek as int,
    endWeek: endWeek == _sentinel ? this.endWeek : endWeek as int,
    notes: notes == _sentinel ? this.notes : notes as String?,
    colorHex: colorHex == _sentinel ? this.colorHex : colorHex as String?,
  );
}

/// Top-level training program (e.g. "12-Week Hypertrophy Block").
///
/// Contains an ordered list of [ProgramWeek]s and named [TrainingPhase]s.
/// Can be created in-app or imported from a JSON file.
class TrainingProgram {
  final String id;
  final String name;
  final String? description;
  final int totalWeeks;
  final List<TrainingPhase> phases;
  final List<ProgramWeek> weeks;
  final String? author;
  final bool isImported;
  final DateTime createdAt;

  TrainingProgram({
    required this.id,
    required this.name,
    this.description,
    required this.totalWeeks,
    required this.phases,
    required this.weeks,
    this.author,
    this.isImported = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Returns the phase that contains [weekNumber], or null.
  TrainingPhase? phaseForWeek(int weekNumber) {
    for (final phase in phases) {
      if (weekNumber >= phase.startWeek && weekNumber <= phase.endWeek) {
        return phase;
      }
    }
    return null;
  }

  /// Number of training days across the entire program.
  int get totalDays =>
      weeks.fold(0, (sum, w) => sum + w.days.length);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'totalWeeks': totalWeeks,
    'phases': phases.map((p) => p.toJson()).toList(),
    'weeks': weeks.map((w) => w.toJson()).toList(),
    'author': author,
    'isImported': isImported,
    'createdAt': createdAt.toIso8601String(),
  };

  factory TrainingProgram.fromJson(Map<String, dynamic> json) =>
      TrainingProgram(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        totalWeeks: json['totalWeeks'] as int,
        phases: (json['phases'] as List)
            .map((p) => TrainingPhase.fromJson(p as Map<String, dynamic>))
            .toList(),
        weeks: (json['weeks'] as List)
            .map((w) => ProgramWeek.fromJson(w as Map<String, dynamic>))
            .toList(),
        author: json['author'] as String?,
        isImported: json['isImported'] as bool? ?? false,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
      );

  TrainingProgram copyWith({
    Object? id = _sentinel,
    Object? name = _sentinel,
    Object? description = _sentinel,
    Object? totalWeeks = _sentinel,
    Object? phases = _sentinel,
    Object? weeks = _sentinel,
    Object? author = _sentinel,
    Object? isImported = _sentinel,
    Object? createdAt = _sentinel,
  }) => TrainingProgram(
    id: id == _sentinel ? this.id : id as String,
    name: name == _sentinel ? this.name : name as String,
    description:
        description == _sentinel ? this.description : description as String?,
    totalWeeks: totalWeeks == _sentinel ? this.totalWeeks : totalWeeks as int,
    phases: phases == _sentinel ? this.phases : phases as List<TrainingPhase>,
    weeks: weeks == _sentinel ? this.weeks : weeks as List<ProgramWeek>,
    author: author == _sentinel ? this.author : author as String?,
    isImported: isImported == _sentinel ? this.isImported : isImported as bool,
    createdAt:
        createdAt == _sentinel ? this.createdAt : createdAt as DateTime,
  );
}

// ==================== AI Coach Chat ====================

/// A single message in an AI coach conversation.
class ChatMessage {
  final String id;
  final String role; // 'user' | 'model'
  final String text;
  final DateTime timestamp;
  // Names of tools the model called (in order) while producing this reply.
  // Null/empty for user messages and replies that used no tools.
  final List<String>? toolCalls;

  ChatMessage({
    String? id,
    required this.role,
    required this.text,
    DateTime? timestamp,
    this.toolCalls,
  })  : id = id ?? _uuid.v4(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
    if (toolCalls != null && toolCalls!.isNotEmpty) 'toolCalls': toolCalls,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String?,
    role: json['role'] as String,
    text: json['text'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    toolCalls: (json['toolCalls'] as List?)?.cast<String>(),
  );

  ChatMessage copyWith({
    Object? role = _sentinel,
    Object? text = _sentinel,
    Object? timestamp = _sentinel,
    Object? toolCalls = _sentinel,
  }) => ChatMessage(
    id: id,
    role: role == _sentinel ? this.role : role as String,
    text: text == _sentinel ? this.text : text as String,
    timestamp: timestamp == _sentinel ? this.timestamp : timestamp as DateTime,
    toolCalls: toolCalls == _sentinel
        ? this.toolCalls
        : toolCalls as List<String>?,
  );
}

/// A persisted AI coach conversation: an ordered list of [ChatMessage]s.
class Conversation {
  final String id;
  final String title;
  final String kind; // 'coach' | 'optimizer'
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessage> messages;

  Conversation({
    String? id,
    required this.title,
    this.kind = 'coach',
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? createdAt ?? DateTime.now(),
        messages = messages ?? const [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'kind': kind,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'messages': messages.map((m) => m.toJson()).toList(),
  };

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    id: json['id'] as String?,
    title: json['title'] as String,
    kind: json['kind'] as String? ?? 'coach',
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: json['updatedAt'] != null
        ? DateTime.parse(json['updatedAt'] as String)
        : DateTime.parse(json['createdAt'] as String),
    messages: (json['messages'] as List)
        .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
        .toList(),
  );

  Conversation copyWith({
    Object? title = _sentinel,
    Object? kind = _sentinel,
    Object? createdAt = _sentinel,
    Object? updatedAt = _sentinel,
    Object? messages = _sentinel,
  }) => Conversation(
    id: id,
    title: title == _sentinel ? this.title : title as String,
    kind: kind == _sentinel ? this.kind : kind as String,
    createdAt: createdAt == _sentinel ? this.createdAt : createdAt as DateTime,
    updatedAt: updatedAt == _sentinel ? this.updatedAt : updatedAt as DateTime,
    messages: messages == _sentinel
        ? this.messages
        : messages as List<ChatMessage>,
  );
}

// ==================== AI Question Models ====================

/// One question the AI asks the user, with predefined options.
class QuestionSpec {
  final String question;
  final List<String> options;
  final bool multiSelect;
  final bool allowCustom;

  const QuestionSpec({
    required this.question,
    required this.options,
    this.multiSelect = false,
    this.allowCustom = true,
  });

  factory QuestionSpec.fromJson(Map<String, dynamic> j) => QuestionSpec(
    question: j['question'] as String,
    options: (j['options'] as List).cast<String>(),
    multiSelect: j['multiSelect'] as bool? ?? false,
    allowCustom: j['allowCustom'] as bool? ?? true,
  );
}

/// The user's answer to one [QuestionSpec].
class AnswerSpec {
  final String question;
  final List<String> selected;
  final String? custom;

  const AnswerSpec({
    required this.question,
    required this.selected,
    this.custom,
  });

  Map<String, Object?> toJson() => {
    'question': question,
    'selected': selected,
    if (custom != null && custom!.isNotEmpty) 'custom': custom,
  };
}

/// The structured payload from an `ask_user_questions` tool call.
class PendingQuestions {
  final String? preamble;
  final List<QuestionSpec> questions;

  const PendingQuestions({this.preamble, required this.questions});

  factory PendingQuestions.fromJson(Map<String, dynamic> j) => PendingQuestions(
    preamble: j['preamble'] as String?,
    questions: (j['questions'] as List)
        .map((q) => QuestionSpec.fromJson(q as Map<String, dynamic>))
        .toList(),
  );
}

// ==================== Readiness ====================

/// Coarse training-readiness classification derived from [ReadinessSnapshot].
enum ReadinessBand { high, moderate, low }

/// A single point-in-time health measurement read from Health Connect.
class HealthSample {
  final DateTime time;
  final double value;

  const HealthSample({required this.time, required this.value});
}

/// One continuous sleep-stage segment within a `SleepPeriod`.
///
/// Stage is one of: `'deep'`, `'rem'`, `'light'`, `'awake'`.
class SleepStageInterval {
  final DateTime start;
  final DateTime end;
  final String stage;

  const SleepStageInterval({
    required this.start,
    required this.end,
    required this.stage,
  });
}

/// A sleep session interval read from Health Connect.
///
/// When stage data is available (from `SleepSessionRecord.samples`),
/// `lightMinutes`, `deepMinutes`, `remMinutes`, and `awakeMinutes` are
/// populated and `minutes` returns actual sleep time (light + deep + rem),
/// excluding awake/out-of-bed spans. Without stage data `minutes` falls back
/// to the raw session duration.
///
/// `stageTimeline` carries the ordered list of stage segments when available,
/// used by the Sleep HR chart to colour-code each 10-minute bar.
class SleepPeriod {
  final DateTime start;
  final DateTime end;

  /// Minutes in light (or unspecified) sleep. Null when no stage data.
  final int? lightMinutes;
  final int? deepMinutes;
  final int? remMinutes;

  /// Awake/out-of-bed minutes within the session window.
  final int? awakeMinutes;

  /// Ordered stage segments, populated from `SleepSessionRecord.samples`.
  /// Empty when the session record carries no stage breakdown.
  final List<SleepStageInterval> stageTimeline;

  const SleepPeriod({
    required this.start,
    required this.end,
    this.lightMinutes,
    this.deepMinutes,
    this.remMinutes,
    this.awakeMinutes,
    this.stageTimeline = const [],
  });

  bool get hasStages =>
      lightMinutes != null || deepMinutes != null || remMinutes != null;

  /// Actual sleep minutes: light + deep + rem when stage data exists,
  /// otherwise the raw session span (start → end).
  int get minutes => hasStages
      ? (lightMinutes ?? 0) + (deepMinutes ?? 0) + (remMinutes ?? 0)
      : end.difference(start).inMinutes;
}

/// Rolling per-component averages used as the personal reference point
/// when scoring today's readiness. Recomputed at most once per day.
class ReadinessBaseline {
  final String dateKey; // yyyy-MM-dd the baseline was computed for
  final double? avgSleepMinutes;
  final int sleepNights;
  final double? avgRestingHr;
  final int rhrDays;
  final double? avgHrvMs;
  final int hrvDays;

  const ReadinessBaseline({
    required this.dateKey,
    this.avgSleepMinutes,
    this.sleepNights = 0,
    this.avgRestingHr,
    this.rhrDays = 0,
    this.avgHrvMs,
    this.hrvDays = 0,
  });

  Map<String, dynamic> toJson() => {
    'dateKey': dateKey,
    'avgSleepMinutes': avgSleepMinutes,
    'sleepNights': sleepNights,
    'avgRestingHr': avgRestingHr,
    'rhrDays': rhrDays,
    'avgHrvMs': avgHrvMs,
    'hrvDays': hrvDays,
  };

  factory ReadinessBaseline.fromJson(Map<String, dynamic> json) =>
      ReadinessBaseline(
        dateKey: json['dateKey'] as String,
        avgSleepMinutes: (json['avgSleepMinutes'] as num?)?.toDouble(),
        sleepNights: json['sleepNights'] as int? ?? 0,
        avgRestingHr: (json['avgRestingHr'] as num?)?.toDouble(),
        rhrDays: json['rhrDays'] as int? ?? 0,
        avgHrvMs: (json['avgHrvMs'] as num?)?.toDouble(),
        hrvDays: json['hrvDays'] as int? ?? 0,
      );
}

/// One day's computed readiness with the per-component evidence behind it.
///
/// Any component (sleep / resting HR / HRV) may be null when the data or a
/// reliable baseline is unavailable; [score] is null when no component could
/// be scored at all, in which case the UI hides readiness entirely.
class ReadinessSnapshot {
  final String dateKey; // yyyy-MM-dd this snapshot describes
  final int? score; // 0–100 overall, null = nothing scorable
  final ReadinessBand? band;
  final int? sleepMinutes;
  final double? sleepBaselineMinutes;
  final int? sleepScore;
  final double? restingHr;
  final double? rhrBaseline;
  final int? rhrScore;
  final double? hrvMs;
  final double? hrvBaseline;
  final int? hrvScore;
  final DateTime computedAt;

  ReadinessSnapshot({
    required this.dateKey,
    this.score,
    this.band,
    this.sleepMinutes,
    this.sleepBaselineMinutes,
    this.sleepScore,
    this.restingHr,
    this.rhrBaseline,
    this.rhrScore,
    this.hrvMs,
    this.hrvBaseline,
    this.hrvScore,
    DateTime? computedAt,
  }) : computedAt = computedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'dateKey': dateKey,
    'score': score,
    'band': band?.name,
    'sleepMinutes': sleepMinutes,
    'sleepBaselineMinutes': sleepBaselineMinutes,
    'sleepScore': sleepScore,
    'restingHr': restingHr,
    'rhrBaseline': rhrBaseline,
    'rhrScore': rhrScore,
    'hrvMs': hrvMs,
    'hrvBaseline': hrvBaseline,
    'hrvScore': hrvScore,
    'computedAt': computedAt.toIso8601String(),
  };

  factory ReadinessSnapshot.fromJson(Map<String, dynamic> json) =>
      ReadinessSnapshot(
        dateKey: json['dateKey'] as String,
        score: json['score'] as int?,
        band: json['band'] != null
            ? ReadinessBand.values.byName(json['band'] as String)
            : null,
        sleepMinutes: json['sleepMinutes'] as int?,
        sleepBaselineMinutes: (json['sleepBaselineMinutes'] as num?)?.toDouble(),
        sleepScore: json['sleepScore'] as int?,
        restingHr: (json['restingHr'] as num?)?.toDouble(),
        rhrBaseline: (json['rhrBaseline'] as num?)?.toDouble(),
        rhrScore: json['rhrScore'] as int?,
        hrvMs: (json['hrvMs'] as num?)?.toDouble(),
        hrvBaseline: (json['hrvBaseline'] as num?)?.toDouble(),
        hrvScore: json['hrvScore'] as int?,
        computedAt: DateTime.parse(json['computedAt'] as String),
      );
}
