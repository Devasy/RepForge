// workout_hr_section.dart — per-workout HR breakdown for the History session
// sheet. Self-hides when Health Connect has no HR data for the workout window.
//
// Shows: avg/peak/min pills, an HR curve with exercise-section flags + rest
// shading (green = HR recovered, amber = didn't), a recovery summary, and an
// expandable per-rest table.

import 'dart:math' show max, min;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../models/workout_hr_models.dart';
import '../../services/managers/health_history_manager.dart';
import '../../services/workout_provider.dart';
import '../../theme/app_theme.dart';
import 'rf_widgets.dart';

class WorkoutHrSection extends StatefulWidget {
  const WorkoutHrSection({super.key, required this.session, required this.provider});

  final WorkoutSession session;
  final WorkoutProvider provider;

  @override
  State<WorkoutHrSection> createState() => _WorkoutHrSectionState();
}

class _WorkoutHrSectionState extends State<WorkoutHrSection> {
  Future<WorkoutHrAnalysis?>? _future;
  bool _expanded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= context.read<HealthHistoryManager>().workoutHr(widget.session);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WorkoutHrAnalysis?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done || snap.data == null) {
          // Self-hide while loading and when there's no HR data.
          return const SizedBox.shrink();
        }
        final a = snap.data!;
        final sections = a.exercises
            .map((e) => _Section(
                  label: _shortName(widget.provider.getExercise(e.exerciseId)?.name ?? '—'),
                  start: e.start,
                  end: e.end,
                ))
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.md),
            const RFSectionHeader('Heart rate'),
            const SizedBox(height: AppSpacing.sm),
            GlassCard(
              padding: const EdgeInsets.all(14),
              borderColor: AppColors.accent.withValues(alpha: 0.18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _Pill(label: 'Avg', value: '${a.avgBpm}', color: AppColors.primary),
                      const SizedBox(width: 6),
                      _Pill(label: 'Peak', value: '${a.peakBpm}', color: AppColors.accent),
                      const SizedBox(width: 6),
                      _Pill(label: 'Min', value: '${a.minBpm}', color: AppColors.secondary),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'HR across the session · ⚑ = exercise',
                        style: TextStyle(fontFamily: 'Geist', color: AppColors.textFaint, fontSize: 11),
                      ),
                      Text('bpm', style: TextStyle(fontFamily: 'Geist', color: AppColors.textFaint, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 150,
                    child: CustomPaint(
                      size: const Size(double.infinity, 150),
                      painter: _CurvePainter(analysis: a, sections: sections),
                    ),
                  ),
                  if (a.hasRestAnalysis && a.restCount > 0) ...[
                    const SizedBox(height: 12),
                    _RecoverySummary(analysis: a),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: AppColors.glass2,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _expanded ? 'Hide per-rest breakdown ▴' : 'Show per-rest breakdown ▾',
                          style: TextStyle(fontFamily: 'Geist', 
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    if (_expanded) ...[
                      const SizedBox(height: 8),
                      ...a.rests.map((r) => _RestRow(rest: r)),
                    ],
                  ] else if (!a.hasRestAnalysis) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Per-rest recovery needs per-set timing, which this workout '
                      'didn\'t record.',
                      style: TextStyle(fontFamily: 'Geist', color: AppColors.textFaint, fontSize: 11, height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static String _shortName(String name) {
    if (name.length <= 14) return name;
    final words = name.split(' ');
    if (words.length >= 2) return '${words.first} ${words[1][0]}.';
    return '${name.substring(0, 12)}…';
  }
}

class _Section {
  final String label;
  final DateTime start;
  final DateTime end;
  const _Section({required this.label, required this.start, required this.end});
}

// ── Recovery summary ──────────────────────────────────────────────────────────

class _RecoverySummary extends StatelessWidget {
  const _RecoverySummary({required this.analysis});
  final WorkoutHrAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final tooShort = analysis.restsTooShort;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.glass2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Text(
            '${analysis.restsRecovered}/${analysis.restCount}',
            style: TextStyle(fontFamily: 'GeistMono', 
              color: AppColors.success,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontFamily: 'Geist', color: AppColors.textMuted, fontSize: 11, height: 1.4),
                children: [
                  const TextSpan(
                    text: 'rests brought your HR down\n',
                    style: TextStyle(color: AppColors.textSoft, fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: 'avg '),
                  TextSpan(
                    text: '−${analysis.avgRecoveryBpm} bpm',
                    style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: ' per rest'),
                  if (tooShort > 0) TextSpan(text: ' · $tooShort too short to drop'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RestRow extends StatelessWidget {
  const _RestRow({required this.rest});
  final RestRecovery rest;

  @override
  Widget build(BuildContext context) {
    final ok = rest.recovered;
    final color = ok ? AppColors.success : AppColors.warning;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(ok ? Icons.check_rounded : Icons.priority_high_rounded, size: 13, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'After set ${rest.afterSet} · rest ${rest.durationSec}s',
                  style: TextStyle(fontFamily: 'Geist', 
                    color: AppColors.textSoft,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'peak ${rest.peakBpm} → low ${rest.troughBpm} bpm${ok ? '' : ' · too short'}',
                  style: TextStyle(fontFamily: 'GeistMono', color: AppColors.textFaint, fontSize: 10),
                ),
              ],
            ),
          ),
          Text(
            '−${rest.recoveryBpm} bpm',
            style: TextStyle(fontFamily: 'GeistMono', color: color, fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ── Pill ──────────────────────────────────────────────────────────────────────

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
              style: TextStyle(fontFamily: 'Geist', color: AppColors.textFaint, fontSize: 9, letterSpacing: 0.5),
            ),
            const SizedBox(height: 2),
            RichText(
              text: TextSpan(children: [
                TextSpan(
                  text: value,
                  style: TextStyle(fontFamily: 'GeistMono', color: color, fontSize: 16, fontWeight: FontWeight.w700),
                ),
                TextSpan(text: ' bpm', style: TextStyle(fontFamily: 'Geist', color: AppColors.textFaint, fontSize: 9)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Curve painter ─────────────────────────────────────────────────────────────

class _CurvePainter extends CustomPainter {
  _CurvePainter({required this.analysis, required this.sections});

  final WorkoutHrAnalysis analysis;
  final List<_Section> sections;

  static const _padLeft = 24.0;
  static const _padTop = 14.0;
  static const _padBottom = 16.0;

  @override
  void paint(Canvas canvas, Size size) {
    final curve = analysis.curve;
    if (curve.isEmpty) return;

    final startMs = analysis.start.millisecondsSinceEpoch;
    final spanMs = max(analysis.end.millisecondsSinceEpoch - startMs, 1);
    final vmin = (analysis.minBpm - 6).toDouble();
    final vmax = (analysis.peakBpm + 6).toDouble();

    final chartW = size.width - _padLeft - 4;
    final chartH = size.height - _padTop - _padBottom;

    double x(DateTime t) =>
        _padLeft + ((t.millisecondsSinceEpoch - startMs) / spanMs).clamp(0.0, 1.0) * chartW;
    double y(double v) => _padTop + chartH - ((v - vmin) / (vmax - vmin)) * chartH;

    // Grid + Y labels.
    final grid = Paint()
      ..color = AppColors.glassBorder
      ..strokeWidth = 0.5;
    final yStyle = TextStyle(fontFamily: 'GeistMono', color: AppColors.textFaint, fontSize: 8);
    for (var v = (vmin / 20).ceil() * 20; v <= vmax; v += 20) {
      final yy = y(v.toDouble());
      canvas.drawLine(Offset(_padLeft, yy), Offset(size.width - 4, yy), grid);
      final tp = TextPainter(
        text: TextSpan(text: '${v.round()}', style: yStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(_padLeft - tp.width - 3, yy - tp.height / 2));
    }

    // Rest shading (green = recovered, amber = not).
    for (final r in analysis.rests) {
      final rx = x(r.restStart);
      final rEnd = x(r.restStart.add(Duration(seconds: r.durationSec)));
      final c = (r.recovered ? AppColors.success : AppColors.warning).withValues(alpha: 0.14);
      canvas.drawRect(Rect.fromLTRB(rx, _padTop, max(rEnd, rx + 1), _padTop + chartH), Paint()..color = c);
    }

    // Area + line.
    final path = Path();
    final area = Path();
    for (var i = 0; i < curve.length; i++) {
      final px = x(curve[i].time);
      final py = y(curve[i].bpm);
      if (i == 0) {
        path.moveTo(px, py);
        area.moveTo(px, y(vmin));
        area.lineTo(px, py);
      } else {
        path.lineTo(px, py);
        area.lineTo(px, py);
      }
    }
    area.lineTo(x(curve.last.time), y(vmin));
    area.close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.accent.withValues(alpha: 0.3), AppColors.accent.withValues(alpha: 0.0)],
        ).createShader(Rect.fromLTWH(_padLeft, _padTop, chartW, chartH)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );

    // Exercise-section flags.
    final flagPaint = Paint()
      ..color = AppColors.textMuted.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (final s in sections) {
      final fx = x(s.start);
      canvas.drawLine(Offset(fx, _padTop), Offset(fx, _padTop + chartH), flagPaint);
      // Flag label chip at top.
      final tp = TextPainter(
        text: TextSpan(
          text: s.label,
          style: TextStyle(fontFamily: 'Geist', color: AppColors.textSoft, fontSize: 8, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 64);
      final lx = min(fx + 3, size.width - 4 - tp.width - 6);
      final chip = Rect.fromLTWH(lx, _padTop - 1, tp.width + 6, 11);
      canvas.drawRRect(
        RRect.fromRectAndRadius(chip, const Radius.circular(3)),
        Paint()..color = AppColors.card.withValues(alpha: 0.92),
      );
      tp.paint(canvas, Offset(lx + 3, _padTop - 0.5));
    }

    // X labels (minutes).
    final xStyle = TextStyle(fontFamily: 'GeistMono', color: AppColors.textFaint, fontSize: 8);
    final totalMin = (spanMs / 60000).round();
    final stepMin = totalMin <= 0 ? 1 : (totalMin / 4).ceil();
    for (var m = 0; m <= totalMin; m += stepMin) {
      final tx = _padLeft + (m * 60000 / spanMs).clamp(0.0, 1.0) * chartW;
      final tp = TextPainter(
        text: TextSpan(text: '${m}m', style: xStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((tx - tp.width / 2).clamp(0, size.width - tp.width), size.height - _padBottom + 4));
    }
  }

  @override
  bool shouldRepaint(_CurvePainter old) => old.analysis != analysis;
}
