import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// 14-week × 7-day activity heatmap grid.
/// [data] is a list of 98 integers (0–4) ordered column-by-column
/// (col 0 = oldest week, row 0 = Mon).
class ActivityHeatmap extends StatelessWidget {
  const ActivityHeatmap({super.key, required this.data});

  final List<int> data; // length 98 (14 cols × 7 rows)

  static const _cols = 14;
  static const _rows = 7;

  // Share the same scale between the calendar and its legend.
  static Color colorForLevel(int value) {
    final level = value.clamp(0, 4);
    return level == 0
        ? AppColors.glass
        : AppColors.activity.withValues(alpha: 0.2 + level * 0.18);
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _cols,
              crossAxisSpacing: 3,
              mainAxisSpacing: 3,
              childAspectRatio: 1,
            ),
            itemCount: _cols * _rows,
            itemBuilder: (context, index) {
              // Transpose: GridView fills row-by-row, we want col-by-col
              final col = index % _cols;
              final row = index ~/ _cols;
              final dataIndex = col * _rows + row;
              final intensity = dataIndex < data.length ? data[dataIndex] : 0;
              return _HeatCell(intensity: intensity);
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Less',
                style: TextStyle(fontSize: 12, color: AppColors.textFaint),
              ),
              Row(
                children: List.generate(5, (i) {
                  return Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: colorForLevel(i),
                    ),
                  );
                }),
              ),
              const Text(
                'More',
                style: TextStyle(fontSize: 12, color: AppColors.textFaint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({required this.intensity});
  final int intensity;

  @override
  Widget build(BuildContext context) {
    final hasGlow = intensity >= 3;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        color: ActivityHeatmap.colorForLevel(intensity),
        boxShadow: hasGlow
            ? [
                BoxShadow(
                  color: AppColors.activity.withValues(alpha: 0.25),
                  blurRadius: 4,
                ),
              ]
            : null,
      ),
    );
  }
}
