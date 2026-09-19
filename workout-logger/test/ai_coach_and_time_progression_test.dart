import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/strategies/progression_rules.dart';
import 'package:repforge/services/ml_service.dart';

void main() {
  group('ChatMessage Multimodal Model Tests', () {
    test('serializes and deserializes imageBytesBase64 and imageMimeType', () {
      final dummyBytes = utf8.encode('fake-image-binary-data');
      final base64Str = base64Encode(dummyBytes);

      final msg = ChatMessage(
        role: 'user',
        text: 'Check my squat depth',
        imageBytesBase64: base64Str,
        imageMimeType: 'image/jpeg',
      );

      final json = msg.toJson();
      expect(json['imageBytesBase64'], base64Str);
      expect(json['imageMimeType'], 'image/jpeg');

      final reconstructed = ChatMessage.fromJson(json);
      expect(reconstructed.role, 'user');
      expect(reconstructed.text, 'Check my squat depth');
      expect(reconstructed.imageBytesBase64, base64Str);
      expect(reconstructed.imageMimeType, 'image/jpeg');
    });

    test('copyWith properly preserves or updates image fields', () {
      final msg = ChatMessage(
        role: 'user',
        text: 'Original',
        imageBytesBase64: 'abc',
        imageMimeType: 'image/png',
      );

      final copied = msg.copyWith(text: 'Updated');
      expect(copied.text, 'Updated');
      expect(copied.imageBytesBase64, 'abc');
      expect(copied.imageMimeType, 'image/png');

      final cleared = msg.copyWith(imageBytesBase64: null);
      expect(cleared.imageBytesBase64, isNull);
    });
  });

  group('Time-Based Set & Progression Tests', () {
    test('WorkoutSet.isTimeBased is true only when reps == 0 and timeTaken > 0', () {
      final repSet = WorkoutSet(weight: 80, reps: 8);
      expect(repSet.isTimeBased, isFalse);

      final timeSet = WorkoutSet(weight: 0, reps: 0, timeTaken: 45);
      expect(timeSet.isTimeBased, isTrue);

      final weightedTimeSet = WorkoutSet(weight: 10, reps: 0, timeTaken: 60);
      expect(weightedTimeSet.isTimeBased, isTrue);
    });

    test('formatHoldDuration formats seconds correctly', () {
      expect(formatHoldDuration(0), '0s');
      expect(formatHoldDuration(-5), '0s');
      expect(formatHoldDuration(45), '45s');
      expect(formatHoldDuration(60), '1m');
      expect(formatHoldDuration(90), '1m 30s');
      expect(formatHoldDuration(120), '2m');
      expect(formatHoldDuration(125), '2m 5s');
    });

    test('WorkoutSet.calculateVolume calculates duration-based volume and formats duration', () {
      final unweightedHold = WorkoutSet(weight: 0, reps: 0, timeTaken: 60);
      expect(unweightedHold.calculateVolume(), 60.0);

      // Weighted hold
      final weightedHold = WorkoutSet(weight: 10, reps: 0, timeTaken: 60);
      expect(weightedHold.calculateVolume(), 600.0);

      expect(unweightedHold.formattedDuration, '1m');
    });

    test('ExerciseLog totalHoldDuration and isTimeBased', () {
      final log = ExerciseLog(
        exerciseId: 'plank',
        sets: [
          WorkoutSet(weight: 0, reps: 0, timeTaken: 45),
          WorkoutSet(weight: 0, reps: 0, timeTaken: 60),
        ],
      );
      expect(log.isTimeBased, isTrue);
      expect(log.totalHoldDuration, 105);
      expect(log.totalVolume, 105.0);

      final mixedLog = ExerciseLog(
        exerciseId: 'bench',
        sets: [
          WorkoutSet(weight: 60, reps: 10),
          WorkoutSet(weight: 0, reps: 0, timeTaken: 30),
        ],
      );
      expect(mixedLog.isTimeBased, isFalse);
    });

    test('DoubleProgressionRule adds 5s hold when duration < ceiling (60s)', () {
      const rule = DoubleProgressionRule();
      final set = WorkoutSet(weight: 0, reps: 0, timeTaken: 45);
      final ctx = ProgressionContext(
        set: set,
        minReps: 6,
        maxReps: 12,
        isPlateau: false,
        isDeclining: false,
        isUnderRecovered: false,
        isPostDeloadRecovery: false,
      );

      final rec = rule.apply(ctx);
      expect(rec.weight, 0);
      expect(rec.reps, 0);
      expect(rec.targetDuration, 50);
      expect(rec.confidence, 'high');
      expect(rec.reasoning, contains('Add 5s hold (50s / 60s target)'));
    });

    test('DoubleProgressionRule steps up weight and resets duration when ceiling (60s) reached', () {
      const rule = DoubleProgressionRule();
      final set = WorkoutSet(weight: 0, reps: 0, timeTaken: 60);
      final ctx = ProgressionContext(
        set: set,
        minReps: 6,
        maxReps: 12,
        isPlateau: false,
        isDeclining: false,
        isUnderRecovered: false,
        isPostDeloadRecovery: false,
      );

      final rec = rule.apply(ctx);
      expect(rec.weight, 2.5); // Adds 2.5kg plate
      expect(rec.reps, 0);
      expect(rec.targetDuration, 30); // Resets to 30s
      expect(rec.confidence, 'high');
      expect(rec.reasoning, contains('step up load and reset to 30s hold'));
    });

    test('UnderRecoveredRule holds duration on time-based set', () {
      const rule = UnderRecoveredRule();
      final set = WorkoutSet(weight: 5, reps: 0, timeTaken: 45);
      final ctx = ProgressionContext(
        set: set,
        minReps: 6,
        maxReps: 12,
        isPlateau: false,
        isDeclining: false,
        isUnderRecovered: true,
        recoveryPercent: 45,
        isPostDeloadRecovery: false,
      );

      final rec = rule.apply(ctx);
      expect(rec, isNotNull);
      expect(rec!.weight, 5);
      expect(rec.targetDuration, 45);
      expect(rec.confidence, 'low');
      expect(rec.reasoning, contains('maintain hold duration'));
    });

    test('ReadinessRule holds duration on time-based set', () {
      const rule = ReadinessRule();
      final set = WorkoutSet(weight: 0, reps: 0, timeTaken: 50);
      final ctx = ProgressionContext(
        set: set,
        minReps: 6,
        maxReps: 12,
        isPlateau: false,
        isDeclining: false,
        isUnderRecovered: false,
        isPostDeloadRecovery: false,
        isLowReadiness: true,
      );

      final rec = rule.apply(ctx);
      expect(rec, isNotNull);
      expect(rec!.weight, 0);
      expect(rec.targetDuration, 50);
      expect(rec.confidence, 'low');
      expect(rec.reasoning, contains('hold duration'));
    });

    test('DeclineDeloadRule deloads duration on time-based set', () {
      const rule = DeclineDeloadRule();
      final set = WorkoutSet(weight: 0, reps: 0, timeTaken: 60);
      final ctx = ProgressionContext(
        set: set,
        minReps: 6,
        maxReps: 12,
        isPlateau: false,
        isDeclining: true,
        isUnderRecovered: false,
        isPostDeloadRecovery: false,
      );

      final rec = rule.apply(ctx);
      expect(rec, isNotNull);
      // 60 * 0.9 = 54 -> rounded to nearest 5 is 55
      expect(rec!.targetDuration, 55);
      expect(rec.confidence, 'medium');
      expect(rec.reasoning, contains('deload ~10%'));
    });

    test('DeclineDeloadRule never recommends hold time exceeding curTime on short holds', () {
      const rule = DeclineDeloadRule();
      final set = WorkoutSet(weight: 0, reps: 0, timeTaken: 10);
      final ctx = ProgressionContext(
        set: set,
        minReps: 6,
        maxReps: 12,
        isPlateau: false,
        isDeclining: true,
        isUnderRecovered: false,
        isPostDeloadRecovery: false,
      );

      final rec = rule.apply(ctx);
      expect(rec, isNotNull);
      expect(rec!.targetDuration, lessThanOrEqualTo(10));
    });

    test('MLService.getDefaultRecommendations produces time-based defaults when isTimeBased is true', () {
      final ml = MLService();
      final recs = ml.getDefaultRecommendations(3, isTimeBased: true);
      expect(recs.length, 3);
      for (final rec in recs) {
        expect(rec.reps, 0);
        expect(rec.weight, 0);
        expect(rec.targetDuration, 30);
        expect(rec.reasoning, contains('30s hold'));
      }
    });
  });
}
