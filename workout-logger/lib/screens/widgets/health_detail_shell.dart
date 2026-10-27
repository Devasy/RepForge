// health_detail_shell.dart — shared scaffold for the Sleep & Heart-rate detail
// screens: ambient background, back button, title, prev/next date nav, and the
// Day/Week/Month/Year granularity toggle. The body is supplied by each screen.

import 'package:flutter/material.dart';

import '../../models/sleep_hr_models.dart';
import '../../theme/app_theme.dart';
import 'rf_widgets.dart';

class HealthDetailShell extends StatelessWidget {
  const HealthDetailShell({
    super.key,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.dateLabel,
    required this.granularity,
    required this.onGranularityChanged,
    required this.onPrev,
    required this.onNext,
    required this.canGoNext,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final String dateLabel;
  final HealthGranularity granularity;
  final ValueChanged<HealthGranularity> onGranularityChanged;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final bool canGoNext;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const AmbientGlow(),
          SafeArea(
            child: Column(
              children: [
                _header(context),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _GranularityToggle(
                    value: granularity,
                    onChanged: onGranularityChanged,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.textSoft,
            ),
            tooltip: 'Back',
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _NavArrow(icon: Icons.chevron_left_rounded, onTap: onPrev),
                const SizedBox(width: 12),
                Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 15, color: iconColor),
                        const SizedBox(width: 5),
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: 'Geist',
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      dateLabel,
                      style: TextStyle(
                        fontFamily: 'GeistMono',
                        color: AppColors.textFaint,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                _NavArrow(
                  icon: Icons.chevron_right_rounded,
                  onTap: canGoNext ? onNext : null,
                ),
              ],
            ),
          ),
          const SizedBox(width: 40), // balance the back button
        ],
      ),
    );
  }
}

class _NavArrow extends StatelessWidget {
  const _NavArrow({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.glass2,
          border: Border.all(color: AppColors.glassBorder),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled
              ? AppColors.textMuted
              : AppColors.textFaint.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

class _GranularityToggle extends StatelessWidget {
  const _GranularityToggle({required this.value, required this.onChanged});

  final HealthGranularity value;
  final ValueChanged<HealthGranularity> onChanged;

  @override
  Widget build(BuildContext context) => RFSelectionGroup<HealthGranularity>(
    compact: true,
    expanded: true,
    options: [
      for (final granularity in HealthGranularity.values)
        RFSelectionOption(value: granularity, label: granularity.label),
    ],
    selected: value,
    onChanged: onChanged,
  );
}
