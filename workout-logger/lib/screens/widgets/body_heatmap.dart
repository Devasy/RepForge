import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:path_parsing/path_parsing.dart';
import 'package:provider/provider.dart';
import '../../services/settings_provider.dart';
import '../../data/body_figure.dart';
export '../../data/body_figure.dart' show BodyFigure;

import '../../data/body_geometry.dart';
import '../../data/exercise_database.dart';
import '../../theme/app_theme.dart';

enum BodyView { front, back }

/// MIT MuscleMap outlines, as used by openGym. Values are relative volume 0–1.
/// Grouped outlines use the strongest matching RepForge muscle, not their sum.
class BodyHeatmapWidget extends StatelessWidget {
  const BodyHeatmapWidget({
    super.key,
    this.muscleVolumes = const {},
    this.width = 74,
    this.height = 148,
    this.view = BodyView.front,
    this.figure,
    this.heatColor = AppColors.primary,
    this.selectedMuscle,
    this.onMuscleTap,
  });

  final Map<String, double> muscleVolumes;
  final double width;
  final double height;
  final BodyView view;
  final BodyFigure? figure;
  final Color heatColor;
  final String? selectedMuscle;
  final ValueChanged<String>? onMuscleTap;

  @override
  Widget build(BuildContext context) {
    final painter = _BodyPainter(
      muscleVolumes: muscleVolumes,
      heatColor: heatColor,
      geometry: _geometry(
        figure ??
            context.watch<SettingsProvider?>()?.bodyFigure ??
            BodyFigure.male,
        view,
      ),
      selectedMuscle: selectedMuscle,
      view: view,
      onMuscleTap: onMuscleTap,
    );
    return SizedBox(
      width: width,
      height: height,
      child: GestureDetector(
        onTapUp: onMuscleTap == null
            ? null
            : (event) {
                final id = painter.muscleAt(
                  event.localPosition,
                  Size(width, height),
                );
                if (id != null) onMuscleTap!(id);
              },
        child: CustomPaint(painter: painter),
      ),
    );
  }
}

/// Detailed side-by-side body map with accessible muscle selection controls.
class MuscleBodyMap extends StatefulWidget {
  const MuscleBodyMap({
    super.key,
    this.muscleVolumes = const {},
    this.selectedMuscle,
    this.onMuscleTap,
    this.showControls = true,
    this.heatColor = AppColors.primary,
  });
  final Map<String, double> muscleVolumes;
  final String? selectedMuscle;
  final ValueChanged<String>? onMuscleTap;
  final bool showControls;
  final Color heatColor;

  @override
  State<MuscleBodyMap> createState() => _MuscleBodyMapState();
}

class _MuscleBodyMapState extends State<MuscleBodyMap> {
  BodyFigure _figure = BodyFigure.male;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider?>();
    final figure = settings?.bodyFigure ?? _figure;
    return Material(
      type: MaterialType.transparency,
      child: Column(
        children: [
          if (widget.showControls) ...[
            SegmentedButton<BodyFigure>(
              segments: const [
                ButtonSegment(value: BodyFigure.male, label: Text('Male')),
                ButtonSegment(value: BodyFigure.female, label: Text('Female')),
              ],
              selected: {figure},
              onSelectionChanged: (value) async {
                if (settings != null) {
                  try {
                    await settings.setBodyFigure(value.single);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Could not save body figure. Try again.',
                          ),
                        ),
                      );
                    }
                  }
                } else {
                  setState(() => _figure = value.single);
                }
              },
            ),
            const SizedBox(height: 12),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final width = math.min(160.0, (constraints.maxWidth - 16) / 2);
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final view in BodyView.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          Text(
                            view == BodyView.front ? 'Front' : 'Back',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          BodyHeatmapWidget(
                            width: width,
                            height: width * 2.2,
                            figure: figure,
                            heatColor: widget.heatColor,
                            view: view,
                            muscleVolumes: widget.muscleVolumes,
                            selectedMuscle: widget.selectedMuscle,
                            onMuscleTap: widget.onMuscleTap,
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          if (widget.showControls) ...[
            const SizedBox(height: 12),
            const Text(
              'Weekly volume relative to your most trained muscle',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'None',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
                for (final level in [0.0, 0.25, 0.5, 0.75, 1.0])
                  Container(
                    width: 18,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: _heatColor(level),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                const Text(
                  'More',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
            if (widget.onMuscleTap != null) ...[
              const SizedBox(height: 10),
              const Text(
                'Tap a region or choose a muscle for details',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final entry in MuscleGroups.names.entries)
                    ActionChip(
                      label: Text(entry.value),
                      onPressed: () => widget.onMuscleTap!(entry.key),
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

const _muscleIds = <String, List<String>>{
  'chest': ['chest', 'upper_chest'],
  'abs': ['core'],
  'obliques': ['core'],
  'biceps': ['biceps'],
  'triceps': ['triceps'],
  'forearm': ['forearms'],
  'quadriceps': ['quads'],
  'hamstring': ['hamstrings'],
  'gluteal': ['glutes'],
  'calves': ['calves'],
  'trapezius': ['traps'],
  'upper-back': ['back', 'lats'],
  'lower-back': ['lower_back'],
};

List<String> _ids(String part, BodyView view) => part == 'deltoids'
    ? [
        'shoulders',
        view == BodyView.front ? 'front_delts' : 'rear_delts',
        'side_delts',
      ]
    : _muscleIds[part] ?? const [];

Color _heatColor(double value, [Color color = AppColors.primary]) => value <= 0
    ? AppColors.glass2
    : Color.lerp(color.withValues(alpha: 0.25), color, value.clamp(0.0, 1.0))!;

class _Geometry {
  _Geometry(Map<String, Object> source) {
    final vb = (source['vb'] as String).split(' ').map(double.parse).toList();
    bounds = Rect.fromLTWH(vb[0], vb[1], vb[2], vb[3]);
    final parts = source['p'] as Map<String, List<String>>;
    paths = {
      for (final part in parts.entries)
        part.key: [
          for (final data in part.value) (_PathReceiver()..parse(data)).path,
        ],
    };
  }
  late final Rect bounds;
  late final Map<String, List<Path>> paths;
}

final _cache = <String, _Geometry>{};
_Geometry _geometry(BodyFigure figure, BodyView view) => _cache.putIfAbsent(
  '${figure.name}/${view.name}',
  () => _Geometry(bodyGeometry[figure.name]![view.name]!),
);

class _PathReceiver extends PathProxy {
  final path = Path();
  void parse(String data) => writeSvgPathDataToPath(data, this);
  @override
  void moveTo(double x, double y) => path.moveTo(x, y);
  @override
  void lineTo(double x, double y) => path.lineTo(x, y);
  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) => path.cubicTo(x1, y1, x2, y2, x3, y3);
  @override
  void close() => path.close();
}

class _BodyPainter extends CustomPainter {
  _BodyPainter({
    required this.muscleVolumes,
    required this.geometry,
    required this.heatColor,
    required this.view,
    this.selectedMuscle,
    this.onMuscleTap,
  });
  final Map<String, double> muscleVolumes;
  final _Geometry geometry;
  final Color heatColor;
  final BodyView view;
  final String? selectedMuscle;
  final ValueChanged<String>? onMuscleTap;

  double _scale(Size size) => math.min(
    size.width / geometry.bounds.width,
    size.height / geometry.bounds.height,
  );
  Offset _origin(Size size) => Offset(
    (size.width - geometry.bounds.width * _scale(size)) / 2,
    (size.height - geometry.bounds.height * _scale(size)) / 2,
  );
  double _volume(String id) {
    final value = muscleVolumes[id] ?? 0;
    return value.isFinite ? value.clamp(0.0, 1.0) : 0;
  }

  String? _target(String part) {
    final ids = _ids(part, view);
    if (ids.isEmpty) return null;
    if (ids.contains(selectedMuscle)) return selectedMuscle;
    return ids.reduce((a, b) => _volume(b) > _volume(a) ? b : a);
  }

  Rect _rect(Path path, Size size) {
    final bounds = path.getBounds();
    final origin = _origin(size);
    final scale = _scale(size);
    return Rect.fromLTWH(
      origin.dx + (bounds.left - geometry.bounds.left) * scale,
      origin.dy + (bounds.top - geometry.bounds.top) * scale,
      bounds.width * scale,
      bounds.height * scale,
    );
  }

  String? muscleAt(Offset position, Size size) {
    final point =
        (position - _origin(size)) / _scale(size) + geometry.bounds.topLeft;
    for (final part in geometry.paths.entries.toList().reversed) {
      if (part.value.any((path) => path.contains(point))) {
        return _target(part.key);
      }
    }
    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = _scale(size);
    final origin = _origin(size);
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scale);
    canvas.translate(-geometry.bounds.left, -geometry.bounds.top);
    for (final part in geometry.paths.entries) {
      final ids = _ids(part.key, view);
      final value = ids.fold(0.0, (v, id) => math.max(v, _volume(id)));
      final selected = ids.contains(selectedMuscle);
      for (final path in part.value) {
        canvas.drawPath(
          path,
          Paint()
            ..color = selected
                ? AppColors.secondary
                : _heatColor(value, heatColor),
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = selected ? AppColors.textPrimary : AppColors.glassBorder
            ..style = PaintingStyle.stroke
            ..strokeWidth = (selected ? 1.3 : 0.5) / scale,
        );
      }
    }
    canvas.restore();
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder =>
      (size) => [
        for (final part in geometry.paths.entries)
          if (_target(part.key) != null)
            CustomPainterSemantics(
              rect: part.value
                  .map((p) => _rect(p, size))
                  .reduce((a, b) => a.expandToInclude(b)),
              properties: SemanticsProperties(
                label: '${MuscleGroups.names[_target(part.key)]}, ${view.name}',
                textDirection: TextDirection.ltr,
                button: onMuscleTap != null,
                selected: _ids(part.key, view).contains(selectedMuscle),
                onTap: onMuscleTap == null
                    ? null
                    : () => onMuscleTap!(_target(part.key)!),
              ),
            ),
      ];
  @override
  bool shouldRepaint(_BodyPainter oldDelegate) =>
      !mapEquals(oldDelegate.muscleVolumes, muscleVolumes) ||
      oldDelegate.geometry != geometry ||
      oldDelegate.selectedMuscle != selectedMuscle ||
      oldDelegate.heatColor != heatColor;
  @override
  bool shouldRebuildSemantics(_BodyPainter oldDelegate) => true;
}
