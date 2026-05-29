// gemini_context_builder.dart — Builds rich context strings from app data for Gemini prompts.

import '../models/models.dart';
import 'interfaces/ml_service_interface.dart';

class GeminiContextBuilder {
  const GeminiContextBuilder._();

  // ── Coach system prompt ────────────────────────────────────────────────────
  static String buildCoachSystemPrompt({
    required List<WorkoutSession> recentSessions,
    required Map<String, Exercise> exerciseMap,
    required Map<String, MuscleRecoveryStatus> recoveryScores,
    required List<Target> activeTargets,
    String? userName,
    String unitLabel = 'kg',
  }) {
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    final buf = StringBuffer()
      ..writeln(
        'You are an expert personal trainer embedded in RepForge, a workout tracking app.',
      )
      ..writeln(
        'Answer concisely (under 180 words unless a plan is requested). '
        'Be encouraging and specific — always reference the user\'s actual data.',
      )
      ..writeln('Today is $today. Use this when interpreting relative dates '
          '("last week", "3 months ago").')
      ..writeln(
        'The snapshot below is recent context only. For anything beyond it — '
        'specific exercise progression, workouts in a date range, routine '
        'performance, personal records, goal progress, or muscle recovery — '
        'CALL THE PROVIDED TOOLS to query the database rather than guessing. '
        'Pass ISO dates (YYYY-MM-DD) or a day count to the tools. '
        'You may format replies with Markdown (lists, bold, tables).',
      );

    if (userName != null && userName.isNotEmpty) {
      buf.writeln('\nUser: $userName');
    }

    // Recent sessions
    buf.writeln('\n--- RECENT SESSIONS (last 14 days) ---');
    final cutoff = DateTime.now().subtract(const Duration(days: 14));
    final recent = recentSessions
        .where((s) => s.date.isAfter(cutoff))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    if (recent.isEmpty) {
      buf.writeln('No sessions in the last 14 days.');
    } else {
      for (final s in recent.take(8)) {
        final date = '${_weekday(s.date.weekday)} ${s.date.day}/${s.date.month}';
        final exParts = s.exercises.map((e) {
          final name = exerciseMap[e.exerciseId]?.name ?? e.exerciseId;
          final sets = e.sets
              .map((ws) => '${ws.weight}$unitLabel×${ws.reps}')
              .join(', ');
          return '$name [$sets]';
        });
        buf.writeln('$date: ${exParts.join(' | ')}');
      }
    }

    // Muscle recovery
    buf.writeln('\n--- MUSCLE RECOVERY ---');
    if (recoveryScores.isEmpty) {
      buf.writeln('No recovery data yet.');
    } else {
      final sorted = recoveryScores.entries.toList()
        ..sort((a, b) => a.value.recoveryPercent.compareTo(b.value.recoveryPercent));
      for (final e in sorted) {
        final name = e.key.replaceAll('_', ' ');
        final pct = e.value.recoveryPercent;
        final tag = e.value.isRecovered
            ? 'ready'
            : e.value.isUnderRecovered
                ? 'fatigued'
                : 'recovering';
        buf.writeln('$name: $pct% ($tag)');
      }
    }

    // Active goals
    buf.writeln('\n--- ACTIVE GOALS ---');
    if (activeTargets.isEmpty) {
      buf.writeln('No active goals set.');
    } else {
      for (final t in activeTargets) {
        final name = exerciseMap[t.exerciseId]?.name ?? t.exerciseId;
        final progress = t.progressPercentage.toStringAsFixed(0);
        buf.writeln(
          '$name: ${t.currentValue}$unitLabel → ${t.targetValue}$unitLabel ($progress%)',
        );
      }
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
