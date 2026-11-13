import 'package:flutter_test/flutter_test.dart';
import 'package:health_connector/health_connector.dart';
import 'package:repforge/services/utils/hc_session_builder.dart';

void main() {
  test(
    'native types shared by exercise variants do not invent an identity',
    () {
      const variants = {
        ExerciseSegmentType.benchPress: [
          'bench_press',
          'incline_bench_press',
          'dumbbell_bench_press',
          'incline_dumbbell_press',
          'close_grip_bench',
        ],
        ExerciseSegmentType.deadlift: ['deadlift', 'romanian_deadlift'],
        ExerciseSegmentType.pullUp: ['pull_ups', 'chin_ups'],
        ExerciseSegmentType.crunch: [
          'crunches',
          'cable_crunch',
          'russian_twist',
        ],
        ExerciseSegmentType.armCurl: [
          'bicep_curl',
          'hammer_curl',
          'preacher_curl',
          'concentration_curl',
        ],
        ExerciseSegmentType.weightlifting: ['push_ups', 'barbell_row'],
      };
      for (final entry in variants.entries) {
        for (final id in entry.value) {
          expect(hcSegmentTypeFor(id), entry.key);
        }
        expect(
          hcExerciseIdFor(entry.key),
          isNull,
          reason: '${entry.key} is ambiguous',
        );
      }
    },
  );

  test('supported unambiguous native identities retain their round trip', () {
    const identities = {
      ExerciseSegmentType.plank: 'plank',
      ExerciseSegmentType.squat: 'squat',
      ExerciseSegmentType.lunge: 'lunges',
      ExerciseSegmentType.legPress: 'leg_press',
      ExerciseSegmentType.legExtension: 'leg_extension',
      ExerciseSegmentType.legCurl: 'leg_curl',
      ExerciseSegmentType.hipThrust: 'hip_thrust',
      ExerciseSegmentType.legRaise: 'leg_raises',
    };
    for (final entry in identities.entries) {
      expect(hcExerciseIdFor(entry.key), entry.value);
      expect(hcSegmentTypeFor(entry.value), entry.key);
    }
  });

  test('unsupported native types stay unidentified', () {
    expect(hcExerciseIdFor(ExerciseSegmentType.otherWorkout), isNull);
    expect(hcExerciseIdFor(ExerciseSegmentType.rest), isNull);
    expect(
      hcSegmentTypeFor('custom-exercise'),
      ExerciseSegmentType.otherWorkout,
    );
  });
}
