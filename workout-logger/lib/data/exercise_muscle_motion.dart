import '../models/models.dart';

/// Illustrative prime movers for standard technique, excluding stabilizers.
/// Activation percentages come from the catalogue; they are not measurements
/// of muscle length or contraction force. Unknown/custom/isometric exercises
/// deliberately have no inferred motion phases.
class ExerciseMuscleMotion {
  const ExerciseMuscleMotion(this.muscles, this.stretched, this.contracted);
  final List<String> muscles;
  final String stretched;
  final String contracted;

  static ExerciseMuscleMotion? forExercise(Exercise exercise) =>
      exercise.isCustom ? null : _motions[exercise.id];
}

const _chestPress = ExerciseMuscleMotion(
  ['chest', 'upper_chest', 'triceps', 'front_delts'],
  'Lower the weight with control toward your chest.',
  'Press the weight away from your chest.',
);
const _chestFly = ExerciseMuscleMotion(
  ['chest'],
  'Open your arms with control.',
  'Bring your arms together.',
);
const _curl = ExerciseMuscleMotion(
  ['biceps'],
  'Lower the weight as your elbows extend.',
  'Curl the weight as your elbows bend.',
);
const _triceps = ExerciseMuscleMotion(
  ['triceps'],
  'Allow your elbows to bend with control.',
  'Extend your elbows against resistance.',
);
const _squat = ExerciseMuscleMotion(
  ['quads', 'glutes'],
  'Lower into the squat as your knees and hips bend.',
  'Stand up by extending your knees and hips.',
);
const _row = ExerciseMuscleMotion(
  ['back', 'lats', 'biceps', 'rear_delts'],
  'Extend your arms and allow your shoulder blades to move forward with control.',
  'Pull toward your torso, drawing your shoulder blades back.',
);
const _pulldown = ExerciseMuscleMotion(
  ['lats', 'biceps'],
  'Return toward the overhead position with control.',
  'Pull down by bending your elbows and bringing your upper arms toward your torso.',
);
const _shoulderPress = ExerciseMuscleMotion(
  ['shoulders', 'triceps'],
  'Lower the weight toward shoulder height with control.',
  'Press the weight overhead.',
);
const _motions = <String, ExerciseMuscleMotion>{
  'bench_press': _chestPress,
  'incline_bench_press': _chestPress,
  'dumbbell_bench_press': _chestPress,
  'incline_dumbbell_press': _chestPress,
  'close_grip_bench': _chestPress,
  'cable_fly': _chestFly,
  'pec_deck': _chestFly,
  'push_ups': ExerciseMuscleMotion(
    ['chest', 'triceps', 'front_delts'],
    'Lower your body toward the floor with control.',
    'Push your body away from the floor.',
  ),
  'dips': ExerciseMuscleMotion(
    ['chest', 'triceps', 'front_delts'],
    'Lower your body as your elbows bend.',
    'Press up by extending your elbows.',
  ),
  'lat_pulldown': _pulldown,
  'pull_ups': ExerciseMuscleMotion(
    ['lats', 'biceps'],
    'Lower your body toward a hang with control.',
    'Pull your body upward.',
  ),
  'chin_ups': ExerciseMuscleMotion(
    ['lats', 'biceps'],
    'Lower your body toward a hang with control.',
    'Pull your body upward.',
  ),
  'barbell_row': _row,
  'dumbbell_row': _row,
  'seated_cable_row': _row,
  't_bar_row': _row,
  'overhead_press': _shoulderPress,
  'dumbbell_shoulder_press': _shoulderPress,
  'lateral_raise': ExerciseMuscleMotion(
    ['side_delts'],
    'Lower your arms toward your sides.',
    'Raise your arms out to your sides.',
  ),
  'front_raise': ExerciseMuscleMotion(
    ['front_delts'],
    'Lower your arms with control.',
    'Raise your arms in front of you.',
  ),
  'rear_delt_fly': ExerciseMuscleMotion(
    ['rear_delts'],
    'Bring your arms forward with control.',
    'Open your arms out to the sides.',
  ),
  'shrugs': ExerciseMuscleMotion(
    ['traps'],
    'Lower your shoulders with control.',
    'Lift your shoulders upward.',
  ),
  'squat': _squat,
  'leg_press': ExerciseMuscleMotion(
    ['quads', 'glutes'],
    'Bring the platform toward you as your knees and hips bend.',
    'Press the platform away by extending your knees and hips.',
  ),
  'leg_extension': ExerciseMuscleMotion(
    ['quads'],
    'Bend your knees as you lower the weight.',
    'Straighten your knees against resistance.',
  ),
  'leg_curl': ExerciseMuscleMotion(
    ['hamstrings'],
    'Extend your knees as you lower the weight.',
    'Bend your knees against resistance.',
  ),
  'romanian_deadlift': ExerciseMuscleMotion(
    ['hamstrings', 'glutes'],
    'Hinge at your hips, moving them back as you lower the weight.',
    'Extend your hips to stand upright.',
  ),
  'hip_thrust': ExerciseMuscleMotion(
    ['glutes'],
    'Lower your hips with control.',
    'Drive your hips upward.',
  ),
  'calf_raise': ExerciseMuscleMotion(
    ['calves'],
    'Lower your heels with control.',
    'Raise your heels by pushing through your forefoot.',
  ),
  'bicep_curl': _curl,
  'hammer_curl': _curl,
  'preacher_curl': _curl,
  'concentration_curl': _curl,
  'tricep_pushdown': _triceps,
  'skull_crushers': _triceps,
  'overhead_tricep_extension': _triceps,
  'crunches': ExerciseMuscleMotion(
    ['core'],
    'Uncurl your torso with control.',
    'Curl your torso toward your pelvis.',
  ),
  'cable_crunch': ExerciseMuscleMotion(
    ['core'],
    'Uncurl your torso with control.',
    'Curl your torso against resistance.',
  ),
};
