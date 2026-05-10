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

  @override
  Widget build(BuildContext context) {
    return Column(
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
            Text(
              'Less',
              style: TextStyle(
                  fontSize: 10, color: AppColors.textFaint),
            ),
            Row(
              children: List.generate(5, (i) {
                final opacity = i == 0 ? 0.05 : 0.2 + i * 0.15;
                return Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: i == 0
                        ? const Color(0x0DFFFFFF)
                        : AppColors.primary.withValues(alpha: opacity),
                  ),
                );
              }),
            ),
            Text(
              'More',
              style: TextStyle(
                  fontSize: 10, color: AppColors.textFaint),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({required this.intensity});
  final int intensity;

  @override
  Widget build(BuildContext context) {
    final opacity = intensity == 0 ? 0.0 : 0.2 + intensity * 0.18;
    final hasGlow = intensity >= 3;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        color: intensity == 0
            ? const Color(0x0AFFFFFF)
            : AppColors.primary.withValues(alpha: opacity.clamp(0, 1)),
        boxShadow: hasGlow
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 4,
                ),
              ]
            : null,
      ),
    );
  }
}
