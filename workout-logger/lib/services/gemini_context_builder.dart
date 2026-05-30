// gemini_context_builder.dart — Builds rich context strings from app data for Gemini prompts.

import '../models/models.dart';

class GeminiContextBuilder {
  const GeminiContextBuilder._();

  // ── Coach system prompt ────────────────────────────────────────────────────
  //
  // Deliberately STATIC (no per-turn workout data) so the prefix stays
  // byte-identical across a conversation and Gemini's implicit prompt caching
  // can engage. All live data is fetched on demand via the coach tools
  // (see CoachToolService), not embedded here.
  static String buildCoachSystemPrompt({
    String? userName,
    String unitLabel = 'kg',
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final today = '${n.year}-${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';

    final buf = StringBuffer()
      ..writeln(
        'You are an expert personal trainer embedded in RepForge, a workout tracking app.',
      )
      ..writeln(
        'Answer concisely (under 180 words unless a plan is requested). '
        'Be encouraging and specific.',
      )
      ..writeln('Today is $today. Use this when interpreting relative dates '
          '("last week", "3 months ago").')
      ..writeln(
        'This prompt contains NO workout data. To answer anything about the '
        'user\'s training — exercise progression, workouts in a date range, '
        'routine performance, personal records, goal progress, or muscle '
        'recovery — CALL THE PROVIDED TOOLS rather than guessing or inventing '
        'numbers. Pass ISO dates (YYYY-MM-DD) or a day count to the tools.',
      )
      ..writeln(
        'Weights are in $unitLabel. Format replies with Markdown (lists, bold, '
        'tables) where it aids clarity.',
      );

    if (userName != null && userName.isNotEmpty) {
      buf.writeln('\nThe user\'s name is $userName.');
    }

    return buf.toString();
  }

  // ── Weekly insights context ────────────────────────────────────────────────
  static String buildWeeklyInsightsContext({
    required List<WorkoutSession> thisWeek,
    required List<WorkoutSession> lastWeek,
    required Map<String, Exercise> exerciseMap,
    String unitLabel = 'kg',
  }) {
    final buf = StringBuffer();

    buf.writeln(
      'THIS WEEK — ${thisWeek.length} sessions, '
      '${_totalVol(thisWeek)}$unitLabel total volume:',
    );
    for (final s in thisWeek) {
      final day = _weekday(s.date.weekday);
      final parts = s.exercises.map((e) {
        final name = exerciseMap[e.exerciseId]?.name ?? e.exerciseId;
        final sets = e.sets.length;
        final vol = e.totalVolume.toStringAsFixed(0);
        return '$name $sets×sets ($vol$unitLabel vol)';
      });
      buf.writeln('  $day: ${parts.join(', ')}');
    }

    buf.writeln(
      '\nLAST WEEK — ${lastWeek.length} sessions, '
      '${_totalVol(lastWeek)}$unitLabel total volume:',
    );
    for (final s in lastWeek) {
      final day = _weekday(s.date.weekday);
      final names =
          s.exercises.map((e) => exerciseMap[e.exerciseId]?.name ?? e.exerciseId);
      buf.writeln('  $day: ${names.join(", ")}');
    }

    return buf.toString();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static String _totalVol(List<WorkoutSession> sessions) =>
      sessions.fold<double>(0, (sum, s) => sum + s.totalVolume).toStringAsFixed(0);

  static String _weekday(int wd) {
    const d = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return d[wd.clamp(1, 7)];
  }
}
