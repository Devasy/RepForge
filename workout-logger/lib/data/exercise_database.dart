// Pre-populated Exercise Database with Muscle Activation Percentages

import '../models/models.dart';

// Muscle Group IDs
class MuscleGroups {
  static const chest = 'chest';
  static const upperChest = 'upper_chest';
  static const back = 'back';
  static const lats = 'lats';
  static const lowerBack = 'lower_back';
  static const shoulders = 'shoulders';
  static const frontDelts = 'front_delts';
  static const sideDelts = 'side_delts';
  static const rearDelts = 'rear_delts';
  static const biceps = 'biceps';
  static const triceps = 'triceps';
  static const forearms = 'forearms';
  static const quads = 'quads';
  static const hamstrings = 'hamstrings';
  static const glutes = 'glutes';
  static const calves = 'calves';
  static const core = 'core';
  static const traps = 'traps';

  static List<MuscleGroup> getAll() => [
    MuscleGroup(id: chest, name: 'Chest'),
    MuscleGroup(id: upperChest, name: 'Upper Chest'),
    MuscleGroup(id: back, name: 'Back'),
    MuscleGroup(id: lats, name: 'Lats'),
    MuscleGroup(id: lowerBack, name: 'Lower Back'),
    MuscleGroup(id: shoulders, name: 'Shoulders'),
    MuscleGroup(id: frontDelts, name: 'Front Delts'),
    MuscleGroup(id: sideDelts, name: 'Side Delts'),
    MuscleGroup(id: rearDelts, name: 'Rear Delts'),
    MuscleGroup(id: biceps, name: 'Biceps'),
    MuscleGroup(id: triceps, name: 'Triceps'),
    MuscleGroup(id: forearms, name: 'Forearms'),
    MuscleGroup(id: quads, name: 'Quadriceps'),
    MuscleGroup(id: hamstrings, name: 'Hamstrings'),
    MuscleGroup(id: glutes, name: 'Glutes'),
    MuscleGroup(id: calves, name: 'Calves'),
    MuscleGroup(id: core, name: 'Core'),
    MuscleGroup(id: traps, name: 'Traps'),
  ];

  static Map<String, String> get names => {
    chest: 'Chest',
    upperChest: 'Upper Chest',
    back: 'Back',
    lats: 'Lats',
    lowerBack: 'Lower Back',
    shoulders: 'Shoulders',
    frontDelts: 'Front Delts',
    sideDelts: 'Side Delts',
    rearDelts: 'Rear Delts',
    biceps: 'Biceps',
    triceps: 'Triceps',
    forearms: 'Forearms',
    quads: 'Quadriceps',
    hamstrings: 'Hamstrings',
    glutes: 'Glutes',
    calves: 'Calves',
    core: 'Core',
    traps: 'Traps',
  };
}

// Pre-populated exercises database
class ExerciseDatabase {
  static List<Exercise> getAll() => [
    // ==================== CHEST ====================
    Exercise(
      id: 'bench_press',
      name: 'Bench Press',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.chest, activationPercentage: 70),
        MuscleActivation(muscleGroupId: MuscleGroups.triceps, activationPercentage: 30),
        MuscleActivation(muscleGroupId: MuscleGroups.frontDelts, activationPercentage: 20),
      ],
      category: 'compound',
    ),
    Exercise(
      id: 'incline_bench_press',
      name: 'Incline Bench Press',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.upperChest, activationPercentage: 65),
        MuscleActivation(muscleGroupId: MuscleGroups.frontDelts, activationPercentage: 30),
        MuscleActivation(muscleGroupId: MuscleGroups.triceps, activationPercentage: 25),
      ],
      category: 'compound',
    ),
    Exercise(
      id: 'dumbbell_bench_press',
      name: 'Dumbbell Bench Press',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.chest, activationPercentage: 75),
        MuscleActivation(muscleGroupId: MuscleGroups.triceps, activationPercentage: 25),
      ],
      category: 'compound',
    ),
    Exercise(
      id: 'incline_dumbbell_press',
      name: 'Incline Dumbbell Press',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.upperChest, activationPercentage: 70),
        MuscleActivation(muscleGroupId: MuscleGroups.frontDelts, activationPercentage: 25),
        MuscleActivation(muscleGroupId: MuscleGroups.triceps, activationPercentage: 20),
      ],
      category: 'compound',
    ),
    Exercise(
      id: 'cable_fly',
      name: 'Cable Fly',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.chest, activationPercentage: 85),
      ],
      category: 'isolation',
    ),
    Exercise(
      id: 'pec_deck',
      name: 'Pec Deck / Machine Fly',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.chest, activationPercentage: 90),
      ],
      category: 'isolation',
    ),
    Exercise(
      id: 'push_ups',
      name: 'Push-ups',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.chest, activationPercentage: 60),
        MuscleActivation(muscleGroupId: MuscleGroups.triceps, activationPercentage: 35),
        MuscleActivation(muscleGroupId: MuscleGroups.frontDelts, activationPercentage: 25),
      ],
      category: 'compound',
    ),
    Exercise(
      id: 'dips',
      name: 'Dips',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.chest, activationPercentage: 55),
        MuscleActivation(muscleGroupId: MuscleGroups.triceps, activationPercentage: 45),
        MuscleActivation(muscleGroupId: MuscleGroups.frontDelts, activationPercentage: 20),
      ],
      category: 'compound',
    ),

    // ==================== BACK ====================
    Exercise(
      id: 'lat_pulldown',
      name: 'Lat Pulldown',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.lats, activationPercentage: 75),
        MuscleActivation(muscleGroupId: MuscleGroups.biceps, activationPercentage: 35),
        MuscleActivation(muscleGroupId: MuscleGroups.rearDelts, activationPercentage: 15),
      ],
      category: 'compound',
    ),
    Exercise(
      id: 'pull_ups',
      name: 'Pull-ups',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.lats, activationPercentage: 80),
        MuscleActivation(muscleGroupId: MuscleGroups.biceps, activationPercentage: 40),
        MuscleActivation(muscleGroupId: MuscleGroups.rearDelts, activationPercentage: 15),
      ],
      category: 'compound',
    ),
    Exercise(
      id: 'chin_ups',
      name: 'Chin-ups',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.lats, activationPercentage: 70),
        MuscleActivation(muscleGroupId: MuscleGroups.biceps, activationPercentage: 50),
      ],
      category: 'compound',
    ),
    Exercise(
      id: 'barbell_row',
      name: 'Barbell Row',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.back, activationPercentage: 70),
        MuscleActivation(muscleGroupId: MuscleGroups.lats, activationPercentage: 50),
        MuscleActivation(muscleGroupId: MuscleGroups.biceps, activationPercentage: 30),
        MuscleActivation(muscleGroupId: MuscleGroups.rearDelts, activationPercentage: 20),
      ],
      category: 'compound',
    ),
    Exercise(
      id: 'dumbbell_row',
      name: 'Dumbbell Row',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.back, activationPercentage: 70),
        MuscleActivation(muscleGroupId: MuscleGroups.lats, activationPercentage: 55),
        MuscleActivation(muscleGroupId: MuscleGroups.biceps, activationPercentage: 30),
      ],
      category: 'compound',
    ),
    Exercise(
      id: 'seated_cable_row',
      name: 'Seated Cable Row',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.back, activationPercentage: 70),
        MuscleActivation(muscleGroupId: MuscleGroups.lats, activationPercentage: 50),
        MuscleActivation(muscleGroupId: MuscleGroups.biceps, activationPercentage: 25),
      ],
      category: 'compound',
    ),
    Exercise(
      id: 't_bar_row',
      name: 'T-Bar Row',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.back, activationPercentage: 75),
        MuscleActivation(muscleGroupId: MuscleGroups.lats, activationPercentage: 45),
        MuscleActivation(muscleGroupId: MuscleGroups.biceps, activationPercentage: 25),
      ],
      category: 'compound',
    ),
    Exercise(
      id: 'deadlift',
      name: 'Deadlift',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.lowerBack, activationPercentage: 50),
        MuscleActivation(muscleGroupId: MuscleGroups.glutes, activationPercentage: 50),
        MuscleActivation(muscleGroupId: MuscleGroups.hamstrings, activationPercentage: 40),
        MuscleActivation(muscleGroupId: MuscleGroups.quads, activationPercentage: 25),
        MuscleActivation(muscleGroupId: MuscleGroups.traps, activationPercentage: 20),
      ],
      category: 'compound',
    ),
    Exercise(
      id: 'face_pull',
      name: 'Face Pull',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.rearDelts, activationPercentage: 80),
        MuscleActivation(muscleGroupId: MuscleGroups.traps, activationPercentage: 30),
        MuscleActivation(muscleGroupId: MuscleGroups.back, activationPercentage: 20),
      ],
      category: 'isolation',
    ),

    // ==================== SHOULDERS ====================
    Exercise(
      id: 'overhead_press',
      name: 'Overhead Press',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.shoulders, activationPercentage: 75),
        MuscleActivation(muscleGroupId: MuscleGroups.triceps, activationPercentage: 30),
        MuscleActivation(muscleGroupId: MuscleGroups.upperChest, activationPercentage: 15),
      ],
      category: 'compound',
    ),
    Exercise(
      id: 'dumbbell_shoulder_press',
      name: 'Dumbbell Shoulder Press',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.shoulders, activationPercentage: 80),
        MuscleActivation(muscleGroupId: MuscleGroups.triceps, activationPercentage: 25),
      ],
      category: 'compound',
    ),
    Exercise(
      id: 'lateral_raise',
      name: 'Lateral Raise',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.sideDelts, activationPercentage: 90),
      ],
      category: 'isolation',
    ),
    Exercise(
      id: 'front_raise',
      name: 'Front Raise',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.frontDelts, activationPercentage: 90),
      ],
      category: 'isolation',
    ),
    Exercise(
      id: 'rear_delt_fly',
      name: 'Rear Delt Fly',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.rearDelts, activationPercentage: 85),
        MuscleActivation(muscleGroupId: MuscleGroups.traps, activationPercentage: 20),
      ],
      category: 'isolation',
    ),
    Exercise(
      id: 'shrugs',
      name: 'Shrugs',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.traps, activationPercentage: 95),
      ],
      category: 'isolation',
    ),

    // ==================== LEGS ====================
    Exercise(
      id: 'squat',
      name: 'Squat',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.quads, activationPercentage: 65),
        MuscleActivation(muscleGroupId: MuscleGroups.glutes, activationPercentage: 50),
        MuscleActivation(muscleGroupId: MuscleGroups.hamstrings, activationPercentage: 25),
        MuscleActivation(muscleGroupId: MuscleGroups.core, activationPercentage: 20),
      ],
      category: 'compound',
    ),
    Exercise(
      id: 'leg_press',
      name: 'Leg Press',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.quads, activationPercentage: 80),
        MuscleActivation(muscleGroupId: MuscleGroups.glutes, activationPercentage: 35),
        MuscleActivation(muscleGroupId: MuscleGroups.hamstrings, activationPercentage: 15),
      ],
      category: 'compound',
    ),
    Exercise(
      id: 'leg_extension',
      name: 'Leg Extension',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.quads, activationPercentage: 95),
      ],
      category: 'isolation',
    ),
    Exercise(
      id: 'leg_curl',
      name: 'Leg Curl',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.hamstrings, activationPercentage: 90),
      ],
      category: 'isolation',
    ),
    Exercise(
      id: 'romanian_deadlift',
      name: 'Romanian Deadlift',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.hamstrings, activationPercentage: 75),
        MuscleActivation(muscleGroupId: MuscleGroups.glutes, activationPercentage: 50),
        MuscleActivation(muscleGroupId: MuscleGroups.lowerBack, activationPercentage: 30),
      ],
      category: 'compound',
    ),
    Exercise(
      id: 'lunges',
      name: 'Lunges',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.quads, activationPercentage: 60),
        MuscleActivation(muscleGroupId: MuscleGroups.glutes, activationPercentage: 55),
        MuscleActivation(muscleGroupId: MuscleGroups.hamstrings, activationPercentage: 25),
      ],
      category: 'compound',
    ),
    Exercise(
      id: 'hip_thrust',
      name: 'Hip Thrust',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.glutes, activationPercentage: 90),
        MuscleActivation(muscleGroupId: MuscleGroups.hamstrings, activationPercentage: 25),
      ],
      category: 'compound',
    ),
    Exercise(
      id: 'calf_raise',
      name: 'Calf Raise',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.calves, activationPercentage: 95),
      ],
      category: 'isolation',
    ),

    // ==================== ARMS ====================
    Exercise(
      id: 'bicep_curl',
      name: 'Bicep Curl',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.biceps, activationPercentage: 95),
      ],
      category: 'isolation',
    ),
    Exercise(
      id: 'hammer_curl',
      name: 'Hammer Curl',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.biceps, activationPercentage: 80),
        MuscleActivation(muscleGroupId: MuscleGroups.forearms, activationPercentage: 40),
      ],
      category: 'isolation',
    ),
    Exercise(
      id: 'preacher_curl',
      name: 'Preacher Curl',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.biceps, activationPercentage: 95),
      ],
      category: 'isolation',
    ),
    Exercise(
      id: 'concentration_curl',
      name: 'Concentration Curl',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.biceps, activationPercentage: 95),
      ],
      category: 'isolation',
    ),
    Exercise(
      id: 'tricep_pushdown',
      name: 'Tricep Pushdown',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.triceps, activationPercentage: 90),
      ],
      category: 'isolation',
    ),
    Exercise(
      id: 'skull_crushers',
      name: 'Skull Crushers',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.triceps, activationPercentage: 90),
      ],
      category: 'isolation',
    ),
    Exercise(
      id: 'overhead_tricep_extension',
      name: 'Overhead Tricep Extension',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.triceps, activationPercentage: 90),
      ],
      category: 'isolation',
    ),
    Exercise(
      id: 'close_grip_bench',
      name: 'Close Grip Bench Press',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.triceps, activationPercentage: 60),
        MuscleActivation(muscleGroupId: MuscleGroups.chest, activationPercentage: 40),
      ],
      category: 'compound',
    ),

    // ==================== CORE ====================
    Exercise(
      id: 'plank',
      name: 'Plank',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.core, activationPercentage: 90),
      ],
      category: 'isolation',
    ),
    Exercise(
      id: 'crunches',
      name: 'Crunches',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.core, activationPercentage: 85),
      ],
      category: 'isolation',
    ),
    Exercise(
      id: 'leg_raises',
      name: 'Leg Raises',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.core, activationPercentage: 80),
      ],
      category: 'isolation',
    ),
    Exercise(
      id: 'russian_twist',
      name: 'Russian Twist',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.core, activationPercentage: 85),
      ],
      category: 'isolation',
    ),
    Exercise(
      id: 'cable_crunch',
      name: 'Cable Crunch',
      muscleActivations: [
        MuscleActivation(muscleGroupId: MuscleGroups.core, activationPercentage: 90),
      ],
      category: 'isolation',
    ),
  ];

  static Exercise? getById(String id) {
    try {
      return getAll().firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  static List<Exercise> getByMuscleGroup(String muscleGroupId) {
    return getAll().where((e) => 
      e.muscleActivations.any((m) => m.muscleGroupId == muscleGroupId)
    ).toList();
  }
}
