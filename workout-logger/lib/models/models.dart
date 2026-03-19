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

// ==================== Training Program Models ====================

/// Rep range suggestion for a specific phase and exercise
class ProgramSetScheme {
  final String phaseId;
  final int sets;
  final int minReps;
  final int maxReps;
  final bool isAmrap; // "AMRAP" — as many reps as possible
  final double? suggestedWeightKg; // Optional starting weight hint

  ProgramSetScheme({
    required this.phaseId,
    required this.sets,
    required this.minReps,
    required this.maxReps,
    this.isAmrap = false,
    this.suggestedWeightKg,
  });

  String get display {
    if (isAmrap) return '$sets × AMRAP';
    if (minReps == maxReps) return '$sets×$minReps';
    return '$sets×$minReps-$maxReps';
  }

  Map<String, dynamic> toJson() => {
    'phaseId': phaseId,
    'sets': sets,
    'minReps': minReps,
    'maxReps': maxReps,
    'isAmrap': isAmrap,
    'suggestedWeightKg': suggestedWeightKg,
  };

  factory ProgramSetScheme.fromJson(Map<String, dynamic> json) =>
      ProgramSetScheme(
        phaseId: json['phaseId'],
        sets: json['sets'],
        minReps: json['minReps'],
        maxReps: json['maxReps'],
        isAmrap: json['isAmrap'] ?? false,
        suggestedWeightKg: (json['suggestedWeightKg'] as num?)?.toDouble(),
      );
}

/// An exercise slot in a program workout day
class ProgramExercise {
  final String id;
  final String exerciseId; // References Exercise in the library
  final String exerciseName; // Stored for display even if exercise not in DB
  final int orderIndex;
  final String? supersetGroup; // 'A', 'B', 'C' — null means standalone
  final List<ProgramSetScheme> setSchemes; // Per-phase set/rep schemes
  final String tempo; // e.g. "3-1-1" (eccentric-pause-concentric)
  final int restSeconds;
  final String? notes; // Coaching cues / form notes

  ProgramExercise({
    required this.id,
    required this.exerciseId,
    required this.exerciseName,
    required this.orderIndex,
    this.supersetGroup,
    required this.setSchemes,
    this.tempo = '2-0-1',
    required this.restSeconds,
    this.notes,
  });

  /// Returns the scheme for a given phase ID, falling back to first available
  ProgramSetScheme? schemeForPhase(String phaseId) {
    final match = setSchemes.where((s) => s.phaseId == phaseId).firstOrNull;
    return match ?? setSchemes.firstOrNull;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'exerciseId': exerciseId,
    'exerciseName': exerciseName,
    'orderIndex': orderIndex,
    'supersetGroup': supersetGroup,
    'setSchemes': setSchemes.map((s) => s.toJson()).toList(),
    'tempo': tempo,
    'restSeconds': restSeconds,
    'notes': notes,
  };

  factory ProgramExercise.fromJson(Map<String, dynamic> json) =>
      ProgramExercise(
        id: json['id'],
        exerciseId: json['exerciseId'],
        exerciseName: json['exerciseName'],
        orderIndex: json['orderIndex'],
        supersetGroup: json['supersetGroup'],
        setSchemes: (json['setSchemes'] as List)
            .map((s) => ProgramSetScheme.fromJson(s))
            .toList(),
        tempo: json['tempo'] ?? '2-0-1',
        restSeconds: json['restSeconds'],
        notes: json['notes'],
      );
}

/// A single day in the program's weekly template
class ProgramWorkoutDay {
  final String id;
  final String dayOfWeek; // 'monday' … 'sunday'
  final String dayType; // 'push', 'pull', 'legs', 'core', 'shoulders', 'rest', 'rehab'
  final String name; // e.g. "PUSH (Chest + Triceps + Front Delt)"
  final String? description;
  final int estimatedDurationMinutes;
  final bool isRestDay;
  final List<ProgramExercise> exercises;

  ProgramWorkoutDay({
    required this.id,
    required this.dayOfWeek,
    required this.dayType,
    required this.name,
    this.description,
    this.estimatedDurationMinutes = 60,
    this.isRestDay = false,
    required this.exercises,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'dayOfWeek': dayOfWeek,
    'dayType': dayType,
    'name': name,
    'description': description,
    'estimatedDurationMinutes': estimatedDurationMinutes,
    'isRestDay': isRestDay,
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };

  factory ProgramWorkoutDay.fromJson(Map<String, dynamic> json) =>
      ProgramWorkoutDay(
        id: json['id'],
        dayOfWeek: json['dayOfWeek'],
        dayType: json['dayType'],
        name: json['name'],
        description: json['description'],
        estimatedDurationMinutes: json['estimatedDurationMinutes'] ?? 60,
        isRestDay: json['isRestDay'] ?? false,
        exercises: (json['exercises'] as List)
            .map((e) => ProgramExercise.fromJson(e))
            .toList(),
      );
}

/// A training phase (e.g. Foundation, Intensify, Peak)
class ProgramPhase {
  final String id;
  final String name;
  final String description;
  final int startWeek;
  final int endWeek;
  final String defaultSetsDisplay; // e.g. "3×10"
  final int defaultRestSeconds;
  final int rpeTarget; // 1–10 RPE
  final bool isDeloadWeek;

  ProgramPhase({
    required this.id,
    required this.name,
    required this.description,
    required this.startWeek,
    required this.endWeek,
    this.defaultSetsDisplay = '3×10',
    this.defaultRestSeconds = 75,
    this.rpeTarget = 7,
    this.isDeloadWeek = false,
  });

  int get durationWeeks => endWeek - startWeek + 1;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'startWeek': startWeek,
    'endWeek': endWeek,
    'defaultSetsDisplay': defaultSetsDisplay,
    'defaultRestSeconds': defaultRestSeconds,
    'rpeTarget': rpeTarget,
    'isDeloadWeek': isDeloadWeek,
  };

  factory ProgramPhase.fromJson(Map<String, dynamic> json) => ProgramPhase(
    id: json['id'],
    name: json['name'],
    description: json['description'],
    startWeek: json['startWeek'],
    endWeek: json['endWeek'],
    defaultSetsDisplay: json['defaultSetsDisplay'] ?? '3×10',
    defaultRestSeconds: json['defaultRestSeconds'] ?? 75,
    rpeTarget: json['rpeTarget'] ?? 7,
    isDeloadWeek: json['isDeloadWeek'] ?? false,
  );
}

/// A specific week target for an exercise in the overload schedule
class WeekTarget {
  final int weekNumber;
  final double targetWeightKg;
  final int targetReps;
  final String? notes;

  WeekTarget({
    required this.weekNumber,
    required this.targetWeightKg,
    required this.targetReps,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'weekNumber': weekNumber,
    'targetWeightKg': targetWeightKg,
    'targetReps': targetReps,
    'notes': notes,
  };

  factory WeekTarget.fromJson(Map<String, dynamic> json) => WeekTarget(
    weekNumber: json['weekNumber'],
    targetWeightKg: (json['targetWeightKg'] as num).toDouble(),
    targetReps: json['targetReps'],
    notes: json['notes'],
  );
}

/// Progressive overload rule for a single exercise in the program
class ProgressionRule {
  final String exerciseId;
  final String exerciseName;
  final String liftType; // 'compound', 'isolation', 'bodyweight'
  final double currentWeightKg;
  final double incrementKg; // Weight added per session when target reps are hit
  final List<WeekTarget> weekTargets;
  final String? keyNote; // e.g. "3s eccentric every rep"

  ProgressionRule({
    required this.exerciseId,
    required this.exerciseName,
    required this.liftType,
    required this.currentWeightKg,
    required this.incrementKg,
    required this.weekTargets,
    this.keyNote,
  });

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'exerciseName': exerciseName,
    'liftType': liftType,
    'currentWeightKg': currentWeightKg,
    'incrementKg': incrementKg,
    'weekTargets': weekTargets.map((w) => w.toJson()).toList(),
    'keyNote': keyNote,
  };

  factory ProgressionRule.fromJson(Map<String, dynamic> json) =>
      ProgressionRule(
        exerciseId: json['exerciseId'],
        exerciseName: json['exerciseName'],
        liftType: json['liftType'],
        currentWeightKg: (json['currentWeightKg'] as num).toDouble(),
        incrementKg: (json['incrementKg'] as num).toDouble(),
        weekTargets: (json['weekTargets'] as List)
            .map((w) => WeekTarget.fromJson(w))
            .toList(),
        keyNote: json['keyNote'],
      );
}

/// Deload week configuration
class DeloadConfig {
  final int weekNumber;
  final double weightReductionPercent; // e.g. 0.15 for 15% reduction
  final int maxSets;
  final String? notes;

  DeloadConfig({
    required this.weekNumber,
    required this.weightReductionPercent,
    required this.maxSets,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'weekNumber': weekNumber,
    'weightReductionPercent': weightReductionPercent,
    'maxSets': maxSets,
    'notes': notes,
  };

  factory DeloadConfig.fromJson(Map<String, dynamic> json) => DeloadConfig(
    weekNumber: json['weekNumber'],
    weightReductionPercent: (json['weightReductionPercent'] as num).toDouble(),
    maxSets: json['maxSets'],
    notes: json['notes'],
  );
}

/// An individual target within a milestone checkpoint
class MilestoneTarget {
  final String description;
  final String? exerciseId;
  final double? targetWeightKg;
  final int? targetReps;

  MilestoneTarget({
    required this.description,
    this.exerciseId,
    this.targetWeightKg,
    this.targetReps,
  });

  Map<String, dynamic> toJson() => {
    'description': description,
    'exerciseId': exerciseId,
    'targetWeightKg': targetWeightKg,
    'targetReps': targetReps,
  };

  factory MilestoneTarget.fromJson(Map<String, dynamic> json) =>
      MilestoneTarget(
        description: json['description'],
        exerciseId: json['exerciseId'],
        targetWeightKg: (json['targetWeightKg'] as num?)?.toDouble(),
        targetReps: json['targetReps'],
      );
}

/// A milestone checkpoint at a specific week
class ProgramMilestone {
  final String id;
  final int weekNumber;
  final String title;
  final String description;
  final String phaseId;
  final List<MilestoneTarget> targets;

  ProgramMilestone({
    required this.id,
    required this.weekNumber,
    required this.title,
    required this.description,
    required this.phaseId,
    required this.targets,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'weekNumber': weekNumber,
    'title': title,
    'description': description,
    'phaseId': phaseId,
    'targets': targets.map((t) => t.toJson()).toList(),
  };

  factory ProgramMilestone.fromJson(Map<String, dynamic> json) =>
      ProgramMilestone(
        id: json['id'],
        weekNumber: json['weekNumber'],
        title: json['title'],
        description: json['description'],
        phaseId: json['phaseId'],
        targets: (json['targets'] as List)
            .map((t) => MilestoneTarget.fromJson(t))
            .toList(),
      );
}

/// Top-level training program (e.g. a 12-week plan)
class TrainingProgram {
  final String id;
  final String name;
  final String description;
  final int durationWeeks;
  final int trainingDaysPerWeek;
  final String? author;
  final DateTime createdAt;
  final bool isImported;
  final List<ProgramPhase> phases;
  final List<ProgramWorkoutDay> weeklySchedule; // Template: one week of days
  final List<ProgramMilestone> milestones;
  final List<ProgressionRule> progressionRules;
  final List<DeloadConfig> deloadWeeks;
  final Map<String, dynamic>? metadata; // Extra program-specific info

  TrainingProgram({
    required this.id,
    required this.name,
    required this.description,
    required this.durationWeeks,
    required this.trainingDaysPerWeek,
    this.author,
    DateTime? createdAt,
    this.isImported = false,
    required this.phases,
    required this.weeklySchedule,
    required this.milestones,
    required this.progressionRules,
    required this.deloadWeeks,
    this.metadata,
  }) : createdAt = createdAt ?? DateTime.now();

  ProgramPhase? phaseForWeek(int weekNumber) {
    for (final phase in phases) {
      if (weekNumber >= phase.startWeek && weekNumber <= phase.endWeek) {
        return phase;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'durationWeeks': durationWeeks,
    'trainingDaysPerWeek': trainingDaysPerWeek,
    'author': author,
    'createdAt': createdAt.toIso8601String(),
    'isImported': isImported,
    'phases': phases.map((p) => p.toJson()).toList(),
    'weeklySchedule': weeklySchedule.map((d) => d.toJson()).toList(),
    'milestones': milestones.map((m) => m.toJson()).toList(),
    'progressionRules': progressionRules.map((r) => r.toJson()).toList(),
    'deloadWeeks': deloadWeeks.map((d) => d.toJson()).toList(),
    'metadata': metadata,
  };

  factory TrainingProgram.fromJson(Map<String, dynamic> json) =>
      TrainingProgram(
        id: json['id'],
        name: json['name'],
        description: json['description'],
        durationWeeks: json['durationWeeks'],
        trainingDaysPerWeek: json['trainingDaysPerWeek'],
        author: json['author'],
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : DateTime.now(),
        isImported: json['isImported'] ?? false,
        phases: (json['phases'] as List)
            .map((p) => ProgramPhase.fromJson(p))
            .toList(),
        weeklySchedule: (json['weeklySchedule'] as List)
            .map((d) => ProgramWorkoutDay.fromJson(d))
            .toList(),
        milestones: (json['milestones'] as List)
            .map((m) => ProgramMilestone.fromJson(m))
            .toList(),
        progressionRules: (json['progressionRules'] as List)
            .map((r) => ProgressionRule.fromJson(r))
            .toList(),
        deloadWeeks: (json['deloadWeeks'] as List)
            .map((d) => DeloadConfig.fromJson(d))
            .toList(),
        metadata: json['metadata'] as Map<String, dynamic>?,
      );
}

/// User's active enrollment in a training program
class ProgramEnrollment {
  final String id;
  final String programId;
  final DateTime startDate;
  int currentWeek;
  bool isActive;
  bool isCompleted;
  final Map<String, bool> completedDays; // key: "week3_monday" → true
  final Map<String, double> currentWeights; // exerciseId → current weight
  final Set<String> completedMilestoneIds;

  ProgramEnrollment({
    required this.id,
    required this.programId,
    required this.startDate,
    this.currentWeek = 1,
    this.isActive = true,
    this.isCompleted = false,
    Map<String, bool>? completedDays,
    Map<String, double>? currentWeights,
    Set<String>? completedMilestoneIds,
  }) : completedDays = completedDays ?? {},
       currentWeights = currentWeights ?? {},
       completedMilestoneIds = completedMilestoneIds ?? {};

  double get progressPercent =>
      (currentWeek / 12 * 100).clamp(0, 100); // approximate

  String dayKey(int week, String dayOfWeek) => 'week${week}_$dayOfWeek';

  bool isDayCompleted(int week, String dayOfWeek) =>
      completedDays[dayKey(week, dayOfWeek)] ?? false;

  Map<String, dynamic> toJson() => {
    'id': id,
    'programId': programId,
    'startDate': startDate.toIso8601String(),
    'currentWeek': currentWeek,
    'isActive': isActive,
    'isCompleted': isCompleted,
    'completedDays': completedDays,
    'currentWeights': currentWeights,
    'completedMilestoneIds': completedMilestoneIds.toList(),
  };

  factory ProgramEnrollment.fromJson(Map<String, dynamic> json) =>
      ProgramEnrollment(
        id: json['id'],
        programId: json['programId'],
        startDate: DateTime.parse(json['startDate']),
        currentWeek: json['currentWeek'] ?? 1,
        isActive: json['isActive'] ?? true,
        isCompleted: json['isCompleted'] ?? false,
        completedDays: Map<String, bool>.from(json['completedDays'] ?? {}),
        currentWeights: (json['currentWeights'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
            {},
        completedMilestoneIds: Set<String>.from(
          (json['completedMilestoneIds'] as List?) ?? [],
        ),
      );

  ProgramEnrollment copyWith({
    Object? currentWeek = _sentinel,
    Object? isActive = _sentinel,
    Object? isCompleted = _sentinel,
    Object? completedDays = _sentinel,
    Object? currentWeights = _sentinel,
    Object? completedMilestoneIds = _sentinel,
  }) => ProgramEnrollment(
    id: id,
    programId: programId,
    startDate: startDate,
    currentWeek: currentWeek == _sentinel ? this.currentWeek : currentWeek as int,
    isActive: isActive == _sentinel ? this.isActive : isActive as bool,
    isCompleted: isCompleted == _sentinel ? this.isCompleted : isCompleted as bool,
    completedDays: completedDays == _sentinel
        ? Map<String, bool>.from(this.completedDays)
        : completedDays as Map<String, bool>,
    currentWeights: currentWeights == _sentinel
        ? Map<String, double>.from(this.currentWeights)
        : currentWeights as Map<String, double>,
    completedMilestoneIds: completedMilestoneIds == _sentinel
        ? Set<String>.from(this.completedMilestoneIds)
        : completedMilestoneIds as Set<String>,
  );
}
