// sleep_detail_screen.dart — full-screen sleep history.
//
// Day  : overnight HR breakdown (SleepHrDayView) for the selected night.
// Week / Month / Year : stacked sleep-duration bars (SleepBarsChart) with an
// 8h goal line and workout-day highlights.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/sleep_hr_models.dart';
import '../services/managers/health_history_manager.dart';
import '../services/workout_provider.dart';
import '../theme/app_theme.dart';
import 'widgets/health_bar_chart.dart';
import 'widgets/health_detail_shell.dart';
import 'widgets/rf_widgets.dart';
import 'widgets/sleep_hr_charts.dart';

class SleepDetailScreen extends StatefulWidget {
  const SleepDetailScreen({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  State<SleepDetailScreen> createState() => _SleepDetailScreenState();
}

class _SleepDetailScreenState extends State<SleepDetailScreen> {
  late HealthHistoryManager _mgr;
  HealthGranularity _g = HealthGranularity.day;
  late DateTime _anchor;
  late Set<String> _workoutDays;
  Future<Object?>? _future;

  @override
  void initState() {
    super.initState();
    final now = widget.initialDate ?? DateTime.now();
    _anchor = DateTime(now.year, now.month, now.day);
    final sessions = context.read<WorkoutProvider>().sessions;
    _workoutDays = sessions.map((s) => HealthHistoryManager.dateKey(s.date)).toSet();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mgr = context.read<HealthHistoryManager>();
    _future ??= _load();
  }

  Future<Object?> _load() => _g == HealthGranularity.day
      ? _mgr.sleepNight(_anchor)
      : _mgr.sleepBars(_anchor, _g);

  bool get _canGoNext {
    final today = DateTime.now();
    return HealthHistoryManager.stepBy(_anchor, _g, 1)
        .isBefore(DateTime(today.year, today.month, today.day + 1));
  }

  void _step(int dir) {
    setState(() {
      _anchor = HealthHistoryManager.stepBy(_anchor, _g, dir);
      _future = _load();
    });
  }

  void _setG(HealthGranularity g) {
    setState(() {
      _g = g;
      _future = _load();
    });
  }

  String get _dateLabel {
    switch (_g) {
      case HealthGranularity.day:
        final prev = _anchor.subtract(const Duration(days: 1));
        return '${DateFormat('MMM d').format(prev)} → ${DateFormat('d').format(_anchor)}';
      case HealthGranularity.week:
        final start = _anchor.subtract(const Duration(days: 6));
        return '${DateFormat('MMM d').format(start)} – ${DateFormat('MMM d').format(_anchor)}';
      case HealthGranularity.month:
        return DateFormat('MMMM yyyy').format(_anchor);
      case HealthGranularity.year:
        return DateFormat('yyyy').format(_anchor);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HealthDetailShell(
      title: 'Sleep',
      icon: Icons.nightlight_round,
      iconColor: kSleepStageColors['rem']!,
      dateLabel: _dateLabel,
      granularity: _g,
      onGranularityChanged: _setG,
      onPrev: () => _step(-1),
      onNext: () => _step(1),
      canGoNext: _canGoNext,
      child: FutureBuilder<Object?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const _Loading();
          }
          if (_g == HealthGranularity.day) {
            final data = snap.data as SleepHrSnapshot?;
            if (data == null) return const _Empty('No sleep data for this night.');
            return _DayBody(snapshot: data);
          }
          final bars = (snap.data as List<SleepDayBar>?) ?? const [];
          return _AggBody(bars: bars, workoutDays: _workoutDays, granularity: _g);
        },
      ),
    );
  }
}

class _DayBody extends StatelessWidget {
  const _DayBody({required this.snapshot});
  final SleepHrSnapshot snapshot;

  static DateTime _ist(DateTime dt) => dt.toUtc().add(const Duration(hours: 5, minutes: 30));
  static String _fmt(DateTime dt) {
    final h = dt.hour == 0 ? 12 : dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m ${dt.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Asleep · ${_fmt(_ist(snapshot.sleepStart))} – ${_fmt(_ist(snapshot.sleepEnd))} IST',
            style: GoogleFonts.geist(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          SleepHrDayView(snapshot: snapshot),
        ],
      ),
    );
  }
}

class _AggBody extends StatelessWidget {
  const _AggBody({
    required this.bars,
    required this.workoutDays,
    required this.granularity,
  });

  final List<SleepDayBar> bars;
  final Set<String> workoutDays;
  final HealthGranularity granularity;

  @override
  Widget build(BuildContext context) {
    final withData = bars.where((b) => b.totalMinutes > 0).toList();
    final avg = withData.isEmpty
        ? 0
        : withData.fold<int>(0, (s, b) => s + b.totalMinutes) ~/ withData.length;
    final avgLabel = '${avg ~/ 60}h${(avg % 60).toString().padLeft(2, '0')}';
    final unit = granularity == HealthGranularity.year ? 'per month' : 'per night';

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sleep duration · $unit',
                style: GoogleFonts.geist(color: AppColors.textFaint, fontSize: 11, letterSpacing: 0.3),
              ),
              Text(
                withData.isEmpty ? '—' : 'avg $avgLabel',
                style: GoogleFonts.geistMono(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SleepBarsChart(bars: bars, workoutDays: workoutDays),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _legend('Deep', kSleepStageColors['deep']!),
              _legend('REM', kSleepStageColors['rem']!),
              _legend('Light', kSleepStageColors['light']!),
              _legendDash('8h goal', kSleepStageColors['awake']!),
              _legend('Workout day', AppColors.accent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(String label, Color c) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.geist(color: AppColors.textFaint, fontSize: 10)),
        ],
      );

  Widget _legendDash(String label, Color c) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 14, height: 2, color: c),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.geist(color: AppColors.textFaint, fontSize: 10)),
        ],
      );
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 220,
        child: Center(child: RFLoadingDots()),
      );
}

class _Empty extends StatelessWidget {
  const _Empty(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
        child: Center(
          child: Text(
            message,
            style: GoogleFonts.geist(color: AppColors.textFaint, fontSize: 13),
          ),
        ),
      );
}
