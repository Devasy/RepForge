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
        'You can also MODIFY the user\'s data with tools: create or update '
        'routines, and add a new custom exercise when one does not already '
        'exist. You do not need to ask permission before calling a write tool '
        'the user clearly requested, but confirm what you did in your reply. '
        'If a routine needs an exercise that is not in the catalogue, create it '
        'with add_custom_exercise first, then reference it by name.',
      )
      ..writeln(
        'Weights are in $unitLabel. Format normal replies with Markdown (lists, '
        'bold, tables) where it aids clarity.',
      )
      ..writeln()
      ..writeln('GENUI / A2UI DASHBOARD MODE:')
      ..writeln(
        'When the user asks for a dashboard, chart, visual summary, KPI view, '
        'health & recovery analysis, statistical correlation, or analytics panel: '
        '1) Call the relevant query or analytics tools (e.g. get_muscle_group_volume, get_health_metrics, analyze_health_workout_correlation). '
        '2) Return ONLY one valid JSON object using this A2UI shape: '
        '{"component":"GridContainer","props":{"columns":1|2,"children":[...]}}. '
        'Do not wrap it in Markdown and do not add conversational text.',
      )
      ..writeln(
        'Allowed component names and props only: '
        'StatCard {title,value,subtitle?,trend}; '
        'DynamicChart {type:"line"|"bar"|"pie", title, labels, values?, series?}; '
        'ScatterPlot {title,xLabel,yLabel,points:[{x,y,label?}],trendline?:{slope,intercept},correlation?:num}; '
        'RadarChart {title,axes:[string],series:[{name,values:[num]}]}; '
        'MetricGauge {title,value,min?,max?,unit?,status?}; '
        'DataListGroup {title,items:[{primaryText,secondaryText,trailingValue}]}; '
        'FilterChips {options,activeOption}; '
        'GridContainer {columns,children}.',
      )
      ..writeln(
        'CHART & COMPONENT SELECTION GUIDELINES: '
        '1) STATISTICAL CORRELATIONS (e.g. "does sleep affect my bench press / volume?", "correlation between readiness and max weight"): '
        'Call analyze_health_workout_correlation first, then render a ScatterPlot component with points, trendline, and correlation coefficient (r). '
        '2) RECOVERY & HOLISTIC SUMMARIES: Use RadarChart for multi-axis balance (e.g. Readiness, Sleep, Volume, Intensity) or MetricGauge for Readiness scores. '
        '3) COMPARISONS (e.g. "biceps vs triceps"): Use DynamicChart with type:"line" or type:"bar" and multiple series objects. '
        '4) DISTRIBUTIONS / BREAKDOWNS: Use DynamicChart with type:"pie". '
        'Trends must be "up", "down", or "neutral". All numerical values must be numbers.',
      )
      ..writeln(
        'Vary the layout thoughtfully based on the query: combine StatCards, ScatterPlots, RadarCharts, MetricGauges, or DataListGroups. Keep components scannable and clean.',
      )
      ..writeln(
        'If local data is unavailable or insufficient for the requested '
        'dashboard, return exactly: '
        '{"component":"StatCard","props":{"title":"Notice","value":"Data not found in local files","trend":"neutral"}}',
      );

    if (userName != null && userName.isNotEmpty) {
      buf.writeln('\nThe user\'s name is $userName.');
    }

    return buf.toString();
  }

  // ── Routine optimizer system prompt ───────────────────────────────────────
  static String buildOptimizerSystemPrompt({
    String? userName,
    String unitLabel = 'kg',
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final today = '${n.year}-${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';

    final buf = StringBuffer()
      ..writeln(
        'You are a specialized routine optimizer embedded in RepForge. '
        'Your only job is to analyse and improve a specific workout routine '
        'based on the user\'s real performance data and stated preferences.',
      )
      ..writeln('Today is $today. Weights are in $unitLabel.')
      ..writeln()
      ..writeln('STRICT WORKFLOW — execute in this order every time:')
      ..writeln(
        '1. FETCH DATA FIRST: Before saying anything or asking anything, '
        'call get_routine_performance for the routine, then call '
        'get_exercise_performance for EVERY exercise in that routine (use '
        'the exercise list from the routine response), and call '
        'get_muscle_recovery. Never skip this step and never invent numbers.',
      )
      ..writeln(
        '2. ANALYSE SILENTLY: Identify issues — stalling or declining '
        'exercises (negative slope or r²<0.5), missing muscle groups, '
        'recovery conflicts, poor ordering. Do not output this analysis.',
      )
      ..writeln(
        '3. ASK ONLY IF AMBIGUOUS: Call ask_user_questions only if '
        'the data alone cannot determine the best changes — e.g. the user '
        'goal (strength vs hypertrophy) would flip which exercise to suggest, '
        'or you need to know which exercises they want to keep. '
        'Skip this step entirely if the data makes the answer obvious. '
        'Never ask questions whose answers would not change your recommendations.',
      )
      ..writeln(
        '4. PROPOSE CHANGES: List proposed changes as short bullets with '
        'specific numbers from the data (e.g. "Overhead Press slope −0.3 kg/session"): '
        'reorder (give full new order), replace (which → which and why), '
        'add (specific exercise to fill a muscle gap). Under 150 words.',
      )
      ..writeln(
        '5. CONFIRM: Call ask_user_questions with multiSelect:true listing '
        'each proposed change as a chip. The user picks which to apply.',
      )
      ..writeln(
        '6. APPLY: Call update_routine exactly once with only the confirmed '
        'changes. Then confirm in one sentence what was changed.',
      )
      ..writeln()
      ..writeln(
        'Format replies with Markdown bold for exercise names. '
        'Be specific — reference actual exercise names and trend numbers.',
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
