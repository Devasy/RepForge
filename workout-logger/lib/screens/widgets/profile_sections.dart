// profile_sections.dart — Section widgets for ProfileScreen

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/settings_provider.dart';
import '../../theme/app_theme.dart';

const String _createdBy = 'Devasy Patel';

// ── Section container ─────────────────────────────────────────────────────────
class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSoft,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(color: AppColors.glassBorder, height: 1),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

// ── Preferences section ───────────────────────────────────────────────────────
class PreferencesSection extends StatelessWidget {
  const PreferencesSection({
    super.key,
    required this.settings,
    required this.onHaptic,
  });

  final SettingsProvider settings;
  final VoidCallback onHaptic;

  @override
  Widget build(BuildContext context) {
    return _ProfileSection(
      icon: Icons.tune_rounded,
      iconColor: AppColors.primary,
      title: 'Preferences',
      subtitle: 'Customize weight display and input steps',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('WEIGHT UNIT'),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _UnitToggleButton(
                  label: 'kg',
                  selected: settings.weightUnit == WeightUnit.kg,
                  onTap: () {
                    onHaptic();
                    settings.setWeightUnit(WeightUnit.kg);
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _UnitToggleButton(
                  label: 'lbs',
                  selected: settings.weightUnit == WeightUnit.lbs,
                  onTap: () {
                    onHaptic();
                    settings.setWeightUnit(WeightUnit.lbs);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const _SectionLabel('WEIGHT INCREMENT'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: settings.availableIncrements.map((inc) {
              final selected = settings.weightIncrement == inc;
              final label = inc == inc.truncateToDouble()
                  ? '${inc.toStringAsFixed(0)} ${settings.unitLabel}'
                  : '${inc.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '')} ${settings.unitLabel}';
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  settings.setWeightIncrement(inc);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.5)
                          : AppColors.glassBorder,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? AppColors.primary : AppColors.textSoft,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Health Connect section ────────────────────────────────────────────────────
class HealthConnectSection extends StatelessWidget {
  const HealthConnectSection({
    super.key,
    required this.settings,
    required this.isLoading,
    required this.onToggle,
  });

  final SettingsProvider settings;
  final bool isLoading;
  final Future<void> Function(bool) onToggle;

  static const _hcColor = Color(0xFF00BFA5);

  @override
  Widget build(BuildContext context) {
    final enabled = settings.healthConnectEnabled;
    return _ProfileSection(
      icon: Icons.monitor_heart_outlined,
      iconColor: _hcColor,
      title: 'Health Connect',
      subtitle: 'Sync workouts to Android Health Connect',
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sync workouts after finishing',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Writes session + per-set reps to Health Connect',
                      style: TextStyle(
                        color: AppColors.textSoft,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                onChanged: isLoading ? null : (v) => onToggle(v),
                activeThumbColor: _hcColor,
                activeTrackColor: _hcColor.withValues(alpha: 0.35),
              ),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: AppSpacing.sm),
            Divider(color: AppColors.glassBorder, height: 1),
            const SizedBox(height: AppSpacing.sm),
            const Row(
              children: [
                Icon(Icons.check_circle_outline, color: _hcColor, size: 16),
                SizedBox(width: 8),
                Text(
                  'Connected — syncing after each workout',
                  style: TextStyle(color: _hcColor, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Data Management section ───────────────────────────────────────────────────
class DataManagementSection extends StatelessWidget {
  const DataManagementSection({
    super.key,
    required this.isExporting,
    required this.isImporting,
    required this.isBackingUp,
    required this.onExport,
    required this.onImport,
    required this.onCloudBackup,
  });

  final bool isExporting;
  final bool isImporting;
  final bool isBackingUp;
  final VoidCallback? onExport;
  final VoidCallback? onImport;
  final VoidCallback? onCloudBackup;

  @override
  Widget build(BuildContext context) {
    return _ProfileSection(
      icon: Icons.storage_rounded,
      iconColor: AppColors.secondary,
      title: 'Data Management',
      subtitle: 'Export, import, or backup your workout data',
      child: Column(
        children: [
          _ActionTile(
            icon: Icons.upload_file_rounded,
            iconColor: AppColors.secondary,
            title: 'Export Backup',
            subtitle: 'Save a local .json backup file',
            loading: isExporting,
            onTap: onExport,
          ),
          _SectionDivider(),
          _ActionTile(
            icon: Icons.download_rounded,
            iconColor: AppColors.secondary,
            title: 'Import Backup',
            subtitle: 'Merge data from a .json backup',
            loading: isImporting,
            onTap: onImport,
          ),
          _SectionDivider(),
          _ActionTile(
            icon: Icons.cloud_upload_outlined,
            iconColor: AppColors.primary,
            title: 'Cloud Backup',
            subtitle: 'Sync to RepForge cloud (requires account)',
            loading: isBackingUp,
            onTap: onCloudBackup,
          ),
        ],
      ),
    );
  }
}

// ── Cloud Sync section (placeholder) ─────────────────────────────────────────
class CloudSyncSection extends StatelessWidget {
  const CloudSyncSection({super.key});

  @override
  Widget build(BuildContext context) {
    return _ProfileSection(
      icon: Icons.sync_rounded,
      iconColor: AppColors.warning,
      title: 'Cloud Sync',
      subtitle: 'Sync your data across devices',
      trailing: _ComingSoonBadge(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('MONGODB CONNECTION STRING'),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: TextField(
              enabled: false,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'mongodb+srv://user:pass@cluster.mongodb.net/db',
                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                prefixIcon: Icon(
                  Icons.link_rounded,
                  color: AppColors.textMuted,
                  size: 18,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm + 4,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Cloud sync with custom MongoDB will be available in a future update.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

// ── About section ─────────────────────────────────────────────────────────────
class AboutSection extends StatelessWidget {
  const AboutSection({super.key, required this.appVersion});
  final String appVersion;

  @override
  Widget build(BuildContext context) {
    return _ProfileSection(
      icon: Icons.info_outline_rounded,
      iconColor: AppColors.textSoft,
      title: 'About',
      subtitle: 'RepForge Workout Logger',
      child: Column(
        children: [
          _InfoTile(label: 'Version', value: appVersion, icon: Icons.tag_rounded),
          _SectionDivider(),
          _InfoTile(label: 'Created by', value: _createdBy, icon: Icons.person_rounded),
          _SectionDivider(),
          _InfoTile(label: 'Platform', value: 'Android', icon: Icons.phone_android_rounded),
          _SectionDivider(),
          _InfoTile(
            label: 'Package',
            value: 'com.devasy.repforge',
            icon: Icons.inventory_2_outlined,
          ),
        ],
      ),
    );
  }
}

// ── Private helpers ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    );
  }
}

class _UnitToggleButton extends StatelessWidget {
  const _UnitToggleButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.5)
                : AppColors.glassBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.primary : AppColors.textSoft,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.loading,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textSoft, fontSize: 12),
      ),
      trailing: loading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 18),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(color: AppColors.textSoft, fontSize: 13),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(color: AppColors.glassBorder, height: 1, indent: 40);
  }
}

class _ComingSoonBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: const Text(
        'Coming Soon',
        style: TextStyle(
          color: AppColors.warning,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
