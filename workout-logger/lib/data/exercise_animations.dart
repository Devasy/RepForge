import '../models/models.dart';

enum ExerciseMovement {
  benchPress,
  fly,
  pushUp,
  dip,
  pullDown,
  pullUp,
  row,
  deadlift,
  facePull,
  shoulderPress,
  lateralRaise,
  frontRaise,
  rearFly,
  shrug,
  squat,
  legPress,
  legExtension,
  legCurl,
  lunge,
  hipThrust,
  calfRaise,
  curl,
  pushDown,
  skullCrusher,
  tricepsExtension,
  plank,
  crunch,
  legRaise,
  twist,
  cableCrunch,
}

enum ExerciseEquipment { none, barbell, dumbbell, cable, machine }

/// Authored movement diagrams for exact catalogue IDs. No name-based guesses
/// are made for custom or downloaded exercises.
class ExerciseAnimation {
  const ExerciseAnimation(
    this.movement,
    this.firstCue,
    this.secondCue, {
    this.equipment = ExerciseEquipment.none,
    this.incline = false,
    this.seated = false,
    this.hinge = false,
    this.supported = false,
  });

  final ExerciseMovement movement;
  final ExerciseEquipment equipment;
  final String firstCue;
  final String secondCue;
  final bool incline;
  final bool seated;
  final bool hinge;
  final bool supported;
  bool get isHold => movement == ExerciseMovement.plank;

  static ExerciseAnimation? forExercise(Exercise exercise) =>
      exercise.isCustom ? null : exerciseAnimations[exercise.id];
}

const exerciseAnimations = <String, ExerciseAnimation>{
  'bench_press': ExerciseAnimation(
    ExerciseMovement.benchPress,
    'Press above your chest',
    'Lower toward your chest',
    equipment: ExerciseEquipment.barbell,
  ),
  'incline_bench_press': ExerciseAnimation(
    ExerciseMovement.benchPress,
    'Press above your upper chest',
    'Lower with control',
    equipment: ExerciseEquipment.barbell,
    incline: true,
  ),
  'dumbbell_bench_press': ExerciseAnimation(
    ExerciseMovement.benchPress,
    'Press the dumbbells up',
    'Lower beside your chest',
    equipment: ExerciseEquipment.dumbbell,
  ),
  'incline_dumbbell_press': ExerciseAnimation(
    ExerciseMovement.benchPress,
    'Press the dumbbells up',
    'Lower with control',
    equipment: ExerciseEquipment.dumbbell,
    incline: true,
  ),
  'cable_fly': ExerciseAnimation(
    ExerciseMovement.fly,
    'Bring your hands together',
    'Open your arms with control',
    equipment: ExerciseEquipment.cable,
  ),
  'pec_deck': ExerciseAnimation(
    ExerciseMovement.fly,
    'Bring the pads together',
    'Return with control',
    equipment: ExerciseEquipment.machine,
    seated: true,
  ),
  'push_ups': ExerciseAnimation(
    ExerciseMovement.pushUp,
    'Lower your chest toward the floor',
    'Push the floor away',
  ),
  'dips': ExerciseAnimation(
    ExerciseMovement.dip,
    'Lower between the bars',
    'Press back up',
  ),
  'lat_pulldown': ExerciseAnimation(
    ExerciseMovement.pullDown,
    'Pull toward your upper chest',
    'Return the bar overhead',
    equipment: ExerciseEquipment.cable,
    seated: true,
  ),
  'pull_ups': ExerciseAnimation(
    ExerciseMovement.pullUp,
    'Pull your body toward the bar',
    'Lower with control',
  ),
  'chin_ups': ExerciseAnimation(
    ExerciseMovement.pullUp,
    'Pull up with palms facing you',
    'Lower with control',
  ),
  'barbell_row': ExerciseAnimation(
    ExerciseMovement.row,
    'Pull toward your lower ribs',
    'Extend your arms with control',
    equipment: ExerciseEquipment.barbell,
    hinge: true,
  ),
  'dumbbell_row': ExerciseAnimation(
    ExerciseMovement.row,
    'Pull the dumbbell toward your hip',
    'Lower with control',
    equipment: ExerciseEquipment.dumbbell,
    hinge: true,
    supported: true,
  ),
  'seated_cable_row': ExerciseAnimation(
    ExerciseMovement.row,
    'Pull the handle toward your torso',
    'Reach forward with control',
    equipment: ExerciseEquipment.cable,
    seated: true,
  ),
  't_bar_row': ExerciseAnimation(
    ExerciseMovement.row,
    'Pull the handle toward your torso',
    'Lower with control',
    equipment: ExerciseEquipment.barbell,
    hinge: true,
    supported: true,
  ),
  'deadlift': ExerciseAnimation(
    ExerciseMovement.deadlift,
    'Stand by extending hips and knees',
    'Lower the bar close to your legs',
    equipment: ExerciseEquipment.barbell,
  ),
  'face_pull': ExerciseAnimation(
    ExerciseMovement.facePull,
    'Pull the rope toward your face',
    'Extend your arms with control',
    equipment: ExerciseEquipment.cable,
  ),
  'overhead_press': ExerciseAnimation(
    ExerciseMovement.shoulderPress,
    'Press the bar overhead',
    'Lower toward your shoulders',
    equipment: ExerciseEquipment.barbell,
  ),
  'dumbbell_shoulder_press': ExerciseAnimation(
    ExerciseMovement.shoulderPress,
    'Press the dumbbells overhead',
    'Lower toward your shoulders',
    equipment: ExerciseEquipment.dumbbell,
    seated: true,
  ),
  'lateral_raise': ExerciseAnimation(
    ExerciseMovement.lateralRaise,
    'Raise your arms out to the sides',
    'Lower with control',
    equipment: ExerciseEquipment.dumbbell,
  ),
  'front_raise': ExerciseAnimation(
    ExerciseMovement.frontRaise,
    'Raise your arms in front',
    'Lower with control',
    equipment: ExerciseEquipment.dumbbell,
  ),
  'rear_delt_fly': ExerciseAnimation(
    ExerciseMovement.rearFly,
    'Open your arms to the sides',
    'Return with control',
    equipment: ExerciseEquipment.dumbbell,
    hinge: true,
  ),
  'shrugs': ExerciseAnimation(
    ExerciseMovement.shrug,
    'Lift your shoulders upward',
    'Lower your shoulders',
    equipment: ExerciseEquipment.dumbbell,
  ),
  'squat': ExerciseAnimation(
    ExerciseMovement.squat,
    'Sit down between your hips',
    'Push through your feet to stand',
    equipment: ExerciseEquipment.barbell,
  ),
  'leg_press': ExerciseAnimation(
    ExerciseMovement.legPress,
    'Press the platform away',
    'Bend your knees with control',
    equipment: ExerciseEquipment.machine,
    seated: true,
  ),
  'leg_extension': ExerciseAnimation(
    ExerciseMovement.legExtension,
    'Straighten your knees',
    'Lower with control',
    equipment: ExerciseEquipment.machine,
    seated: true,
  ),
  'leg_curl': ExerciseAnimation(
    ExerciseMovement.legCurl,
    'Bend your knees',
    'Lower with control',
    equipment: ExerciseEquipment.machine,
  ),
  'romanian_deadlift': ExerciseAnimation(
    ExerciseMovement.deadlift,
    'Bring your hips forward to stand',
    'Hinge back with soft knees',
    equipment: ExerciseEquipment.barbell,
    hinge: true,
  ),
  'lunges': ExerciseAnimation(
    ExerciseMovement.lunge,
    'Lower into a split stance',
    'Push through your front foot to rise',
    equipment: ExerciseEquipment.dumbbell,
  ),
  'hip_thrust': ExerciseAnimation(
    ExerciseMovement.hipThrust,
    'Raise your hips',
    'Lower with control',
    equipment: ExerciseEquipment.barbell,
    supported: true,
  ),
  'calf_raise': ExerciseAnimation(
    ExerciseMovement.calfRaise,
    'Rise onto the balls of your feet',
    'Lower your heels',
    equipment: ExerciseEquipment.machine,
  ),
  'bicep_curl': ExerciseAnimation(
    ExerciseMovement.curl,
    'Curl without moving your upper arms',
    'Lower with control',
    equipment: ExerciseEquipment.barbell,
  ),
  'hammer_curl': ExerciseAnimation(
    ExerciseMovement.curl,
    'Curl with palms facing inward',
    'Lower with control',
    equipment: ExerciseEquipment.dumbbell,
  ),
  'preacher_curl': ExerciseAnimation(
    ExerciseMovement.curl,
    'Curl with upper arms on the pad',
    'Extend with control',
    equipment: ExerciseEquipment.dumbbell,
    seated: true,
    supported: true,
  ),
  'concentration_curl': ExerciseAnimation(
    ExerciseMovement.curl,
    'Curl with your elbow against your thigh',
    'Lower with control',
    equipment: ExerciseEquipment.dumbbell,
    seated: true,
    hinge: true,
  ),
  'tricep_pushdown': ExerciseAnimation(
    ExerciseMovement.pushDown,
    'Extend your elbows downward',
    'Return with upper arms still',
    equipment: ExerciseEquipment.cable,
  ),
  'skull_crushers': ExerciseAnimation(
    ExerciseMovement.skullCrusher,
    'Extend your elbows above your chest',
    'Bend your elbows with control',
    equipment: ExerciseEquipment.barbell,
  ),
  'overhead_tricep_extension': ExerciseAnimation(
    ExerciseMovement.tricepsExtension,
    'Extend your elbows overhead',
    'Lower behind your head',
    equipment: ExerciseEquipment.dumbbell,
  ),
  'close_grip_bench': ExerciseAnimation(
    ExerciseMovement.benchPress,
    'Press with a close grip',
    'Lower toward your chest',
    equipment: ExerciseEquipment.barbell,
  ),
  'plank': ExerciseAnimation(
    ExerciseMovement.plank,
    'Hold a straight line from head to heels',
    'Breathe steadily and keep your hips level',
  ),
  'crunches': ExerciseAnimation(
    ExerciseMovement.crunch,
    'Lift your shoulders off the floor',
    'Lower with control',
  ),
  'leg_raises': ExerciseAnimation(
    ExerciseMovement.legRaise,
    'Raise your legs',
    'Lower with control',
  ),
  'russian_twist': ExerciseAnimation(
    ExerciseMovement.twist,
    'Rotate your torso to one side',
    'Rotate toward the other side',
  ),
  'cable_crunch': ExerciseAnimation(
    ExerciseMovement.cableCrunch,
    'Curl your ribs toward your hips',
    'Return with control',
    equipment: ExerciseEquipment.cable,
  ),
};
