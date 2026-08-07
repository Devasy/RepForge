import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/genui/a2ui.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/gemini_context_builder.dart';

void main() {
  group('GeminiContextBuilder', () {
    test('buildCoachSystemPrompt includes today date, unit label, and username', () {
      final now = DateTime(2026, 7, 23);
      final prompt = GeminiContextBuilder.buildCoachSystemPrompt(
        userName: 'Devasy',
        unitLabel: 'lbs',
        now: now,
      );

      expect(prompt, contains('Today is 2026-07-23'));
      expect(prompt, contains('Weights are in lbs'));
      expect(prompt, contains("The user's name is Devasy"));
      expect(prompt, contains('RepForge'));
    });

    test('buildOptimizerSystemPrompt builds routine optimizer system prompt', () {
      final now = DateTime(2026, 7, 23);
      final prompt = GeminiContextBuilder.buildOptimizerSystemPrompt(
        userName: 'Devasy',
        unitLabel: 'kg',
        now: now,
      );

      expect(prompt, contains('specialized routine optimizer'));
      expect(prompt, contains('Today is 2026-07-23'));
      expect(prompt, contains('Weights are in kg'));
      expect(prompt, contains("The user's name is Devasy"));
    });

    test('buildWeeklyInsightsContext formats sessions and volumes for this and last week', () {
      final exerciseMap = <String, Exercise>{
        'ex1': Exercise(
          id: 'ex1',
          name: 'Bench Press',
          category: 'compound',
          muscleActivations: [
            MuscleActivation(muscleGroupId: 'chest', activationPercentage: 100),
          ],
        ),
      };

      final thisWeekSession = WorkoutSession(
        id: 's1',
        date: DateTime(2026, 7, 20), // Monday
        duration: 45,
        exercises: [
          ExerciseLog(
            exerciseId: 'ex1',
            sets: [
              WorkoutSet(weight: 100, reps: 10),
            ],
          ),
        ],
      );

      final lastWeekSession = WorkoutSession(
        id: 's2',
        date: DateTime(2026, 7, 13), // Monday
        duration: 45,
        exercises: [
          ExerciseLog(
            exerciseId: 'ex1',
            sets: [
              WorkoutSet(weight: 95, reps: 10),
            ],
          ),
        ],
      );

      final result = GeminiContextBuilder.buildWeeklyInsightsContext(
        thisWeek: [thisWeekSession],
        lastWeek: [lastWeekSession],
        exerciseMap: exerciseMap,
        unitLabel: 'kg',
      );

      expect(result, contains('THIS WEEK — 1 sessions'));
      expect(result, contains('Bench Press 1×sets (1000kg vol)'));
      expect(result, contains('LAST WEEK — 1 sessions'));
      expect(result, contains('Mon: Bench Press'));
    });
  });

  group('coach prompt A2UI section', () {
    final prompt = GeminiContextBuilder.buildCoachSystemPrompt(
      now: DateTime(2026, 8, 5),
    );

    test('embeds the generated A2UI section', () {
      expect(prompt, contains(buildA2UiPromptSection(defaultA2UiRegistry)));
    });

    test('no longer hand-writes component schemas', () {
      // The old prose listed props inline; the generated section owns that now.
      expect(prompt, isNot(contains('StatCard {title,value,subtitle?,trend}')));
      expect(prompt, isNot(contains('RadarChart {title,axes:[string]')));
    });

    test('domain playbook survives and names components only', () {
      expect(prompt, contains('biceps vs triceps'));
      expect(prompt, contains('get_sleeping_hr_analytics'));
    });

    test('is stable for a fixed date so the cache prefix stays byte-identical',
        () {
      expect(
        GeminiContextBuilder.buildCoachSystemPrompt(now: DateTime(2026, 8, 5)),
        prompt,
      );
    });

    // Pins the hand-written "WHICH COMPONENT TO REACH FOR" playbook against
    // drift: this prose can't be generated from the registry (it's
    // domain-specific routing guidance a domain-free lib/genui/ package can't
    // know about), so if a component named here is ever renamed or removed
    // from the registry, this test must fail loudly rather than the mismatch
    // going silent the way it did before the registry refactor.
    test(
        'every component named in the WHICH COMPONENT TO REACH FOR playbook '
        'resolves in the default registry', () {
      // Names as semantically referenced by the prose (e.g. the prose says
      // "StatCards" — the plural reads naturally in a sentence but the
      // canonical component is "StatCard"; `contains` below tolerates the
      // trailing "s").
      const mentionedComponents = [
        'DynamicChart',
        'StatCard',
        'ScatterPlot',
        'RadarChart',
        'MetricGauge',
        'DataListGroup',
      ];

      for (final name in mentionedComponents) {
        expect(
          prompt,
          contains(name),
          reason: '"$name" is expected in the component-routing playbook '
              'but was not found — did the prose get edited?',
        );
        expect(
          defaultA2UiRegistry.specFor(name),
          isNotNull,
          reason: '"$name" is named in the component-routing playbook but '
              'does not resolve in defaultA2UiRegistry — it was likely '
              'renamed or removed without updating the prose.',
        );
      }
    });

    test('default registry has exactly the expected number of components',
        () {
      // A deliberate, visible tripwire: if a component is ever added or
      // removed, this assertion should force a conscious update rather than
      // the count silently drifting.
      expect(defaultA2UiRegistry.specs.length, 8);
    });
  });
}
