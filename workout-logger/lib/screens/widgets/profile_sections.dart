// profile_sections.dart — Section widgets for ProfileScreen

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/settings_provider.dart';
import '../../services/ai/gemini_ai_service.dart';
import '../../theme/app_theme.dart';
import 'rf_widgets.dart';

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
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: iconColor.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.geist(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.geist(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(color: AppColors.glassBorder, height: 1),
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
                        : AppColors.glass,
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
                    style: GoogleFonts.geistMono(
                      color: selected ? AppColors.primary : AppColors.textSoft,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(color: AppColors.glassBorder, height: 1),
          const SizedBox(height: AppSpacing.md),
          const _SectionLabel('ADVANCED METRICS'),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Show estimated 1RM',
                      style: GoogleFonts.geist(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Display 1-rep max badge on completed sets',
                      style: GoogleFonts.geist(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: settings.showAdvancedMetrics,
                onChanged: (v) {
                  onHaptic();
                  settings.setShowAdvancedMetrics(v);
                },
                activeThumbColor: AppColors.primary,
                activeTrackColor: AppColors.primary.withValues(alpha: 0.35),
              ),
            ],
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sync workouts after finishing',
                      style: GoogleFonts.geist(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Writes session + per-set reps to Health Connect',
                      style: GoogleFonts.geist(
                        color: AppColors.textMuted,
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
            const Divider(color: AppColors.glassBorder, height: 1),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(Icons.check_circle_outline, color: _hcColor, size: 15),
                const SizedBox(width: 8),
                Text(
                  'Connected — syncing after each workout',
                  style: GoogleFonts.geist(color: _hcColor, fontSize: 12),
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
          const _SectionDivider(),
          _ActionTile(
            icon: Icons.download_rounded,
            iconColor: AppColors.secondary,
            title: 'Import Backup',
            subtitle: 'Merge data from a .json backup',
            loading: isImporting,
            onTap: onImport,
          ),
          const _SectionDivider(),
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
      trailing: const _ComingSoonBadge(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('MONGODB CONNECTION STRING'),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: AppColors.glass,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: TextField(
              enabled: false,
              style: GoogleFonts.geistMono(
                color: AppColors.textFaint,
                fontSize: 12,
              ),
              decoration: InputDecoration(
                hintText: 'mongodb+srv://user:pass@cluster.mongodb.net/db',
                hintStyle: GoogleFonts.geistMono(
                  color: AppColors.textFaint,
                  fontSize: 12,
                ),
                prefixIcon: const Icon(
                  Icons.link_rounded,
                  color: AppColors.textFaint,
                  size: 16,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm + 4,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Cloud sync with custom MongoDB will be available in a future update.',
            style: GoogleFonts.geist(
              color: AppColors.textFaint,
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
          _InfoTile(
            label: 'Version',
            value: appVersion,
            icon: Icons.tag_rounded,
          ),
          const _SectionDivider(),
          _InfoTile(
            label: 'Created by',
            value: _createdBy,
            icon: Icons.person_rounded,
          ),
          const _SectionDivider(),
          _InfoTile(
            label: 'Platform',
            value: 'Android',
            icon: Icons.phone_android_rounded,
          ),
          const _SectionDivider(),
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
      style: GoogleFonts.geistMono(
        color: AppColors.textFaint,
        fontSize: 9,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
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
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.glass,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.5)
                : AppColors.glassBorder,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primaryGlow(0.20),
                    blurRadius: 12,
                    spreadRadius: -4,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.geist(
              color: selected ? AppColors.primary : AppColors.textSoft,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 14,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      splashColor: AppColors.primary.withValues(alpha: 0.06),
      highlightColor: AppColors.primary.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: iconColor.withValues(alpha: 0.22),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.geist(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.geist(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (loading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            else
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textFaint,
                size: 18,
              ),
          ],
        ),
      ),
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
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textFaint, size: 16),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.geist(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.geistMono(
              color: AppColors.textSoft,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      color: AppColors.glassBorder,
      height: 1,
      indent: 40,
    );
  }
}

// ── AI Features section ───────────────────────────────────────────────────────
class AiSettingsSection extends StatefulWidget {
  const AiSettingsSection({super.key});

  @override
  State<AiSettingsSection> createState() => _AiSettingsSectionState();
}

class _AiSettingsSectionState extends State<AiSettingsSection> {
  late TextEditingController _ctrl;
  bool _obscure = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: context.read<SettingsProvider>().geminiApiKey,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final key = _ctrl.text.trim();
    final settings = context.read<SettingsProvider>();
    final gemini = context.read<GeminiAiService>();
    try {
      await settings.setGeminiApiKey(key);
      gemini.updateApiKey(key);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _selectModel(String modelId) async {
    final settings = context.read<SettingsProvider>();
    final gemini = context.read<GeminiAiService>();
    await settings.setGeminiModel(modelId);
    gemini.updateModel(modelId);
  }

  @override
  Widget build(BuildContext context) {
    final gemini = context.watch<GeminiAiService>();
    final settings = context.watch<SettingsProvider>();
    return _ProfileSection(
      icon: Icons.auto_awesome_rounded,
      iconColor: AppColors.primary,
      title: 'AI Features',
      subtitle: 'Gemini-powered coach, program builder & insights',
      trailing: gemini.isConfigured
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
              ),
              child: Text(
                'Active',
                style: GoogleFonts.geist(
                  color: AppColors.success,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('GEMINI API KEY'),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: AppColors.glass,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.glassBorderStrong),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    obscureText: _obscure,
                    enableSuggestions: false,
                    autocorrect: false,
                    keyboardType: TextInputType.visiblePassword,
                    style: GoogleFonts.geistMono(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                    ),
                    decoration: InputDecoration(
                      hintText: 'AIza…',
                      hintStyle: GoogleFonts.geistMono(
                        color: AppColors.textFaint,
                        fontSize: 12,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm + 4,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _obscure = !_obscure),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: Icon(
                      _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: AppColors.textFaint,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Get a free key at aistudio.google.com. Stored locally on-device.',
            style: GoogleFonts.geist(
              color: AppColors.textFaint,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const _SectionLabel('GEMINI MODEL'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kGeminiModels.map(((String, String) entry) {
              final (id, label) = entry;
              final selected = settings.geminiModel == id;
              return GestureDetector(
                onTap: () => _selectModel(id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.glass,
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
                    style: GoogleFonts.geistMono(
                      color: selected ? AppColors.primary : AppColors.textSoft,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      fontSize: 11,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
              ),
              child: TextButton(
                onPressed: _saving ? null : _save,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          valueColor: AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      )
                    : Text(
                        'Save API Key',
                        style: GoogleFonts.geist(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComingSoonBadge extends StatelessWidget {
  const _ComingSoonBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Text(
        'Soon',
        style: GoogleFonts.geist(
          color: AppColors.warning,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
