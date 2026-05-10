import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class CalendarDayData {
  const CalendarDayData({required this.intensity, this.hasPr = false});
  final int intensity; // 1–3
  final bool hasPr;
}

/// Calendar month grid with intensity shading and PR dot indicators.
class CalendarMonthGrid extends StatelessWidget {
  const CalendarMonthGrid({
    super.key,
    required this.year,
    required this.month,
    required this.workoutDays,
    this.selectedDay,
    this.onDayTap,
  });

  final int year;
  final int month;
  final Map<int, CalendarDayData> workoutDays;
  final int? selectedDay;
  final ValueChanged<int>? onDayTap;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(year, month, 1);
    final startOffset = (firstDay.weekday - 1) % 7;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final today = DateTime.now();
    final isCurrentMonth = today.year == year && today.month == month;
    final todayDay = isCurrentMonth ? today.day : -1;
    final totalCells = ((startOffset + daysInMonth) / 7).ceil() * 7;

    return Column(
      children: [
        Row(
          children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
              .map((d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: GoogleFonts.geist(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textFaint,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            childAspectRatio: 1,
          ),
          itemCount: totalCells,
          itemBuilder: (context, i) {
            final day = i - startOffset + 1;
            if (day < 1 || day > daysInMonth) {
              return const SizedBox.shrink();
            }
            final data = workoutDays[day];
            final isToday = day == todayDay;
            final isSelected = day == selectedDay;
            final isFuture = isCurrentMonth && day > today.day;

            return _DayCell(
              day: day,
              data: data,
              isToday: isToday,
              isSelected: isSelected,
              isFuture: isFuture,
              onTap: data != null ? () => onDayTap?.call(day) : null,
            );
          },
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 4),
                Text('PR',
                    style: TextStyle(fontSize: 10, color: AppColors.textFaint)),
              ],
            ),
            Row(
              children: [
                Text('Less',
                    style: TextStyle(fontSize: 10, color: AppColors.textFaint)),
                const SizedBox(width: 6),
                ...List.generate(4, (i) {
                  final Color c;
                  if (i == 0) {
                    c = Colors.transparent;
                  } else if (i == 1) {
                    c = AppColors.primary.withValues(alpha: 0.15);
                  } else if (i == 2) {
                    c = AppColors.primary.withValues(alpha: 0.55);
                  } else {
                    c = AppColors.primary;
                  }
                  return Container(
                    width: 9,
                    height: 9,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: c,
                      border: i == 0
                          ? Border.all(color: AppColors.glassBorder)
                          : null,
                    ),
                  );
                }),
                const SizedBox(width: 6),
                Text('More',
                    style: TextStyle(fontSize: 10, color: AppColors.textFaint)),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.data,
    required this.isToday,
    required this.isSelected,
    required this.isFuture,
    this.onTap,
  });

  final int day;
  final CalendarDayData? data;
  final bool isToday;
  final bool isSelected;
  final bool isFuture;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final intensity = data?.intensity ?? 0;
    final Color bg;
    if (intensity == 0) {
      bg = Colors.transparent;
    } else if (intensity == 1) {
      bg = AppColors.primary.withValues(alpha: 0.15);
    } else if (intensity == 2) {
      bg = AppColors.primary.withValues(alpha: 0.55);
    } else {
      bg = AppColors.primary;
    }

    final Border? border;
    if (isSelected) {
      border = Border.all(color: AppColors.primary, width: 1.5);
    } else if (isToday) {
      border = Border.all(color: AppColors.textMuted, width: 1);
    } else {
      border = null;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: bg,
          border: border,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                '$day',
                style: GoogleFonts.geistMono(
                  fontSize: 12,
                  fontWeight:
                      intensity > 0 ? FontWeight.w600 : FontWeight.w400,
                  color: intensity > 1
                      ? Colors.white
                      : isFuture
                          ? AppColors.textFaint
                          : AppColors.textPrimary,
                ),
              ),
            ),
            if (data?.hasPr == true)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.success,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
