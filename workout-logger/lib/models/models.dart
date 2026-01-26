// Data Models for Workout Logger App

// Sentinel value for copyWith methods to distinguish "not provided" from "null"
const Object _sentinel = Object();

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

class Exercise {
  final String id;
  final String name;
  final List<MuscleActivation> muscleActivations;
  final String category; // 'compound' or 'isolation'
  final bool isCustom; // User-created exercise

  Exercise({
    required this.id,
    required this.name,
    required this.muscleActivations,
    required this.category,
    this.isCustom = false,
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
  };

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
    id: json['id'],
    name: json['name'],
    muscleActivations: (json['muscleActivations'] as List)
        .map((m) => MuscleActivation.fromJson(m))
        .toList(),
    category: json['category'],
    isCustom: json['isCustom'] ?? false,
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

  WorkoutSet({
    required this.weight,
    required this.reps,
    this.isDropset = false,
    this.drops,
    this.timeTaken,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  double get volume {
    double vol = weight * reps;
    if (isDropset && drops != null) {
      for (var drop in drops!) {
        vol += drop.weight * drop.reps;
      }
    }
    return vol;
  }

  Map<String, dynamic> toJson() => {
    'weight': weight,
    'reps': reps,
    'isDropset': isDropset,
    'drops': drops?.map((d) => d.toJson()).toList(),
    'timeTaken': timeTaken,
    'timestamp': timestamp.toIso8601String(),
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
  );

  WorkoutSet copyWith({
    Object? weight = _sentinel,
    Object? reps = _sentinel,
    Object? isDropset = _sentinel,
    Object? drops = _sentinel,
    Object? timeTaken = _sentinel,
    Object? timestamp = _sentinel,
  }) => WorkoutSet(
    weight: weight == _sentinel ? this.weight : weight as double,
    reps: reps == _sentinel ? this.reps : reps as int,
    isDropset: isDropset == _sentinel ? this.isDropset : isDropset as bool,
    drops: drops == _sentinel ? this.drops : drops as List<DropsetEntry>?,
    timeTaken: timeTaken == _sentinel ? this.timeTaken : timeTaken as int?,
    timestamp: timestamp == _sentinel ? this.timestamp : timestamp as DateTime?,
  );
}

class DropsetEntry {
  final double weight;
  final int reps;

  DropsetEntry({required this.weight, required this.reps});

  Map<String, dynamic> toJson() => {'weight': weight, 'reps': reps};

  factory DropsetEntry.fromJson(Map<String, dynamic> json) => DropsetEntry(
    weight: (json['weight'] as num).toDouble(),
    reps: json['reps'],
  );
}

// ==================== Exercise Log ====================

class ExerciseLog {
  final String exerciseId;
  final List<WorkoutSet> sets;
  final String? notes;

  ExerciseLog({required this.exerciseId, required this.sets, this.notes});

  double get totalVolume => sets.fold(0.0, (sum, set) => sum + set.volume);

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'sets': sets.map((s) => s.toJson()).toList(),
    'notes': notes,
  };

  factory ExerciseLog.fromJson(Map<String, dynamic> json) => ExerciseLog(
    exerciseId: json['exerciseId'],
    sets: (json['sets'] as List).map((s) => WorkoutSet.fromJson(s)).toList(),
    notes: json['notes'],
  );

  ExerciseLog copyWith({
    Object? exerciseId = _sentinel,
    Object? sets = _sentinel,
    Object? notes = _sentinel,
  }) => ExerciseLog(
    exerciseId: exerciseId == _sentinel
        ? this.exerciseId
        : exerciseId as String,
    sets: sets == _sentinel ? this.sets : sets as List<WorkoutSet>,
    notes: notes == _sentinel ? this.notes : notes as String?,
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

  WorkoutSession({
    required this.id,
    required this.date,
    this.routineId,
    required this.exercises,
    required this.duration,
    this.notes,
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
  );

  WorkoutSession copyWith({
    Object? id = _sentinel,
    Object? date = _sentinel,
    Object? routineId = _sentinel,
    Object? exercises = _sentinel,
    Object? duration = _sentinel,
    Object? notes = _sentinel,
  }) => WorkoutSession(
    id: id == _sentinel ? this.id : id as String,
    date: date == _sentinel ? this.date : date as DateTime,
    routineId: routineId == _sentinel ? this.routineId : routineId as String?,
    exercises: exercises == _sentinel
        ? this.exercises
        : exercises as List<ExerciseLog>,
    duration: duration == _sentinel ? this.duration : duration as int,
    notes: notes == _sentinel ? this.notes : notes as String?,
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

class GrowthModel {
  final double slope; // Growth rate per session
  final double intercept; // Starting baseline
  final double r2; // Model fit quality (0-1)
  final DateTime lastTrained;

  GrowthModel({
    required this.slope,
    required this.intercept,
    required this.r2,
    required this.lastTrained,
  });

  double predict(int sessionNumber) {
    return slope * sessionNumber + intercept;
  }
}
