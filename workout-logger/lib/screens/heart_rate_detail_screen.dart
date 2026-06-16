// heart_rate_detail_screen.dart — full-screen all-day heart-rate history.
//
// Day  : ~30-min min–max HR bars + resting line for the selected day.
// Week / Month / Year : daily/monthly min–max range bars with resting markers.

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

class HeartRateDetailScreen extends StatefulWidget {
  const HeartRateDetailScreen({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  State<HeartRateDetailScreen> createState() => _HeartRateDetailScreenState();
}

class _HeartRateDetailScreenState extends State<HeartRateDetailScreen> {
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
      ? _mgr.hrDay(_anchor)
      : _mgr.hrBars(_anchor, _g);

  bool get _canGoNext {
    final today = DateTime.now();
    return HealthHistoryManager.stepBy(_anchor, _g, 1)
        .isBefore(DateTime(today.year, today.month, today.day + 1));
  }

  void _step(int dir) => setState(() {
        _anchor = HealthHistoryManager.stepBy(_anchor, _g, dir);
        _future = _load();
      });

  void _setG(HealthGranularity g) => setState(() {
        _g = g;
        _future = _load();
      });

  String get _dateLabel {
    switch (_g) {
      case HealthGranularity.day:
        return DateFormat('EEE · MMM d').format(_anchor);
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
      title: 'Heart rate',
      icon: Icons.favorite_rounded,
      iconColor: AppColors.accent,
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
            return const SizedBox(height: 220, child: Center(child: RFLoadingDots()));
          }
          if (_g == HealthGranularity.day) {
            final data = snap.data as HrDaySnapshot?;
            if (data == null) return const _Empty('No heart-rate data for this day.');
            return _DayBody(snapshot: data);
          }
          final bars = (snap.data as List<HrRangeBar>?) ?? const [];
          return _AggBody(bars: bars, workoutDays: _workoutDays, granularity: _g);
        },
      ),
    );
  }
}

class _DayBody extends StatelessWidget {
  const _DayBody({required this.snapshot});
  final HrDaySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _Pill(label: 'Resting', value: snapshot.restingBpm?.toString() ?? '—', color: AppColors.secondary),
            const SizedBox(width: 6),
            _Pill(label: 'Min', value: '${snapshot.minBpm}', color: AppColors.textMuted),
            const SizedBox(width: 6),
            _Pill(label: 'Max', value: '${snapshot.maxBpm}', color: AppColors.accent),
            const SizedBox(width: 6),
            _Pill(label: 'Avg', value: '${snapshot.avgBpm.round()}', color: AppColors.primary),
          ],
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'All-day heart rate · 30-min bars',
                    style: GoogleFonts.geist(color: AppColors.textFaint, fontSize: 11, letterSpacing: 0.3),
                  ),
                  Text('bpm', style: GoogleFonts.geist(color: AppColors.textFaint, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 8),
              HrDayChart(snapshot: snapshot),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                children: [
                  _legend('Min–max', AppColors.secondary),
                  _legendDash('Resting', AppColors.secondary),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legend(String label, Color c) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
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

class _AggBody extends StatelessWidget {
  const _AggBody({required this.bars, required this.workoutDays, required this.granularity});

  final List<HrRangeBar> bars;
  final Set<String> workoutDays;
  final HealthGranularity granularity;

  @override
  Widget build(BuildContext context) {
    final withData = bars.where((b) => b.maxBpm > 0).toList();
    final resting = withData.where((b) => b.restingBpm != null).map((b) => b.restingBpm!).toList();
    final avgRest = resting.isEmpty ? null : (resting.reduce((a, b) => a + b) / resting.length).round();
    final mn = withData.isEmpty ? null : withData.map((b) => b.minBpm).reduce((a, b) => a < b ? a : b);
    final mx = withData.isEmpty ? null : withData.map((b) => b.maxBpm).reduce((a, b) => a > b ? a : b);
    final unit = granularity == HealthGranularity.year ? 'monthly' : 'daily';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _Pill(label: 'Avg resting', value: avgRest?.toString() ?? '—', color: AppColors.secondary),
            const SizedBox(width: 6),
            _Pill(label: 'Min', value: mn?.toString() ?? '—', color: AppColors.textMuted),
            const SizedBox(width: 6),
            _Pill(label: 'Max', value: mx?.toString() ?? '—', color: AppColors.accent),
          ],
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$unit range · resting ●',
                style: GoogleFonts.geist(color: AppColors.textFaint, fontSize: 11, letterSpacing: 0.3),
              ),
              const SizedBox(height: 12),
              HrRangeChart(bars: bars, workoutDays: workoutDays),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                children: [
                  _legend('Min–max', AppColors.primary),
                  _legend('Resting', AppColors.secondary),
                  _legend('Workout day', AppColors.accent),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legend(String label, Color c) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.geist(color: AppColors.textFaint, fontSize: 10)),
        ],
      );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.glass2,
          border: Border.all(color: AppColors.glassBorder),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: GoogleFonts.geist(color: AppColors.textFaint, fontSize: 9, letterSpacing: 0.5),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.geistMono(color: color, fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
        child: Center(
          child: Text(message, style: GoogleFonts.geist(color: AppColors.textFaint, fontSize: 13)),
        ),
      );
}
