// profile_sections.dart — Section widgets for ProfileScreen

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/debug_log_buffer.dart';
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
                      style: TextStyle(fontFamily: 'Geist', 
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontFamily: 'Geist', 
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
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
                  duration: AppDurations.fast,
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
                    style: TextStyle(fontFamily: 'GeistMono', 
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
                      style: TextStyle(fontFamily: 'Geist', 
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Display 1-rep max badge on completed sets',
                      style: TextStyle(fontFamily: 'Geist', 
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
    required this.isReadinessLoading,
    required this.onReadinessToggle,
    required this.isHealthSyncLoading,
    required this.onHealthSyncNow,
  });

  final SettingsProvider settings;
  final bool isLoading;
  final Future<void> Function(bool) onToggle;
  final bool isReadinessLoading;
  final Future<void> Function(bool) onReadinessToggle;
  final bool isHealthSyncLoading;
  final VoidCallback? onHealthSyncNow;

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
                      style: TextStyle(fontFamily: 'Geist', 
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Writes session + per-set reps to Health Connect',
                      style: TextStyle(fontFamily: 'Geist', 
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
                  style: TextStyle(fontFamily: 'Geist', color: _hcColor, fontSize: 12),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          const Divider(color: AppColors.glassBorder, height: 1),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Readiness insights',
                      style: TextStyle(fontFamily: 'Geist', 
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Reads sleep & heart data to score daily recovery',
                      style: TextStyle(fontFamily: 'Geist', 
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: settings.readinessEnabled,
                onChanged:
                    isReadinessLoading ? null : (v) => onReadinessToggle(v),
                activeThumbColor: _hcColor,
                activeTrackColor: _hcColor.withValues(alpha: 0.35),
              ),
            ],
          ),
          if (settings.readinessEnabled) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(color: AppColors.glassBorder, height: 1),
            const SizedBox(height: AppSpacing.sm),
            _ActionTile(
              icon: Icons.sync_rounded,
              iconColor: _hcColor,
              title: 'Sync coach data now',
              subtitle: "Pull recent sleep & heart rate into the coach's database",
              loading: isHealthSyncLoading,
              onTap: isHealthSyncLoading ? null : onHealthSyncNow,
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
    required this.onExport,
    required this.onImport,
  });

  final bool isExporting;
  final bool isImporting;
  final VoidCallback? onExport;
  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) {
    return _ProfileSection(
      icon: Icons.storage_rounded,
      iconColor: AppColors.secondary,
      title: 'Data Management',
      subtitle: 'Export or import your workout data',
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
        ],
      ),
    );
  }
}

// ── About section ─────────────────────────────────────────────────────────────
class AboutSection extends StatefulWidget {
  const AboutSection({super.key, required this.appVersion});
  final String appVersion;

  @override
  State<AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends State<AboutSection> {
  int _versionTaps = 0;

  void _onVersionTap() {
    _versionTaps++;
    if (_versionTaps >= 5) {
      _versionTaps = 0;
      _showDebugLogs(context);
    }
  }

  void _showDebugLogs(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => const _DebugLogSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ProfileSection(
      icon: Icons.info_outline_rounded,
      iconColor: AppColors.textSoft,
      title: 'About',
      subtitle: 'RepForge Workout Logger',
      child: Column(
        children: [
          GestureDetector(
            onTap: _onVersionTap,
            child: _InfoTile(
              label: 'Version',
              value: widget.appVersion,
              icon: Icons.tag_rounded,
            ),
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
      style: TextStyle(fontFamily: 'GeistMono', 
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
        duration: AppDurations.fast,
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
            style: TextStyle(fontFamily: 'Geist', 
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
                    style: TextStyle(fontFamily: 'Geist', 
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontFamily: 'Geist', 
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
            style: TextStyle(fontFamily: 'Geist', 
              color: AppColors.textMuted,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(fontFamily: 'GeistMono', 
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

  // Live value shown while dragging the slider; null when not dragging (in
  // which case the persisted settings value is shown instead).
  double? _draggingMaxToolRounds;
  double? _draggingThinkingLevelIndex;

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

  Future<void> _commitMaxToolRounds(int rounds) async {
    // onChangeEnd discards this Future, so a storage failure would otherwise
    // surface as an unhandled error; and the await means the widget can be
    // disposed before setState runs.
    try {
      await context.read<SettingsProvider>().setGeminiMaxToolRounds(rounds);
    } catch (e, st) {
      debugPrint('Failed to save max tool rounds: $e\n$st');
    } finally {
      if (mounted) {
        setState(() => _draggingMaxToolRounds = null);
      }
    }
  }

  Future<void> _commitThinkingLevel(String level) async {
    // Same contract as _commitMaxToolRounds above: onChangeEnd drops the
    // Future, and the widget may be gone by the time the await returns.
    final gemini = context.read<GeminiAiService>();
    try {
      await context.read<SettingsProvider>().setGeminiThinkingLevel(level);
      gemini.updateThinkingLevel(level);
    } catch (e, st) {
      debugPrint('Failed to save thinking level: $e\n$st');
    } finally {
      if (mounted) {
        setState(() => _draggingThinkingLevelIndex = null);
      }
    }
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
                style: TextStyle(fontFamily: 'Geist', 
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
                    style: TextStyle(fontFamily: 'GeistMono', 
                      color: AppColors.textPrimary,
                      fontSize: 12,
                    ),
                    decoration: InputDecoration(
                      hintText: 'AIza…',
                      hintStyle: TextStyle(fontFamily: 'GeistMono', 
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
            style: TextStyle(fontFamily: 'Geist', 
              color: AppColors.textFaint,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const _SectionLabel('GEMINI MODEL'),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: AppColors.glass,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.glassBorderStrong),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButtonFormField<String>(
                key: ValueKey(settings.geminiModel),
                initialValue: settings.geminiModel,
                isExpanded: true,
                isDense: false,
                dropdownColor: AppColors.card,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textFaint),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                ),
                style: TextStyle(fontFamily: 'GeistMono',
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
                items: kGeminiModels.map(((String, String) entry) {
                  final (id, label) = entry;
                  return DropdownMenuItem(value: id, child: Text(label));
                }).toList(),
                onChanged: (id) {
                  if (id != null) _selectModel(id);
                },
              ),
            ),
          ),
          if (supportedThinkingLevels(settings.geminiModel).isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            const _SectionLabel('THINKING LEVEL'),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'How much the model reasons before replying. Lower is faster and cheaper; higher is more capable on hard problems.',
              style: TextStyle(fontFamily: 'Geist',
                color: AppColors.textFaint,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Builder(builder: (context) {
              final levels = supportedThinkingLevels(settings.geminiModel);
              final currentIndex = levels.indexOf(settings.geminiThinkingLevel);
              final liveIndex = _draggingThinkingLevelIndex ??
                  (currentIndex >= 0 ? currentIndex.toDouble() : 0.0);
              final liveLevel = levels[liveIndex.round().clamp(0, levels.length - 1)];
              final liveLevelLabel = liveLevel[0].toUpperCase() + liveLevel.substring(1);
              return Row(
                children: [
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor: AppColors.glassBorderStrong,
                        thumbColor: AppColors.primary,
                        overlayColor: AppColors.primary.withValues(alpha: 0.15),
                        valueIndicatorColor: AppColors.primary,
                        trackHeight: 3,
                      ),
                      child: Slider(
                        value: liveIndex,
                        min: 0,
                        max: (levels.length - 1).toDouble(),
                        divisions: levels.length > 1 ? levels.length - 1 : null,
                        label: liveLevelLabel,
                        onChanged: (v) {
                          setState(() => _draggingThinkingLevelIndex = v);
                          context.read<GeminiAiService>().updateThinkingLevel(
                            levels[v.round().clamp(0, levels.length - 1)],
                          );
                        },
                        onChangeEnd: (v) => _commitThinkingLevel(
                          levels[v.round().clamp(0, levels.length - 1)],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      liveLevelLabel,
                      style: TextStyle(fontFamily: 'GeistMono',
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
          const SizedBox(height: AppSpacing.md),
          const _SectionLabel('MAX TOOL-CALL STEPS'),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'How many tool rounds the coach can take per message before it must reply. Raise this if it stops mid-task; lower it to limit token usage.',
            style: TextStyle(fontFamily: 'Geist',
              color: AppColors.textFaint,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Builder(builder: (context) {
            final liveValue =
                _draggingMaxToolRounds ?? settings.geminiMaxToolRounds.toDouble();
            return Row(
              children: [
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: AppColors.glassBorderStrong,
                      thumbColor: AppColors.primary,
                      overlayColor: AppColors.primary.withValues(alpha: 0.15),
                      valueIndicatorColor: AppColors.primary,
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: liveValue,
                      min: kMinMaxToolRounds.toDouble(),
                      max: kMaxMaxToolRounds.toDouble(),
                      divisions: kMaxMaxToolRounds - kMinMaxToolRounds,
                      label: '${liveValue.round()}',
                      onChanged: (v) {
                        setState(() => _draggingMaxToolRounds = v);
                        context.read<GeminiAiService>().updateMaxToolRounds(v.round());
                      },
                      onChangeEnd: (v) => _commitMaxToolRounds(v.round()),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    '${liveValue.round()}',
                    style: TextStyle(fontFamily: 'GeistMono',
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: AnimatedContainer(
              duration: AppDurations.fast,
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
                        style: TextStyle(fontFamily: 'Geist', 
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const _SectionLabel('TOKEN USAGE'),
              const Spacer(),
              if (gemini.aiRequestCount > 0)
                GestureDetector(
                  onTap: () => context.read<GeminiAiService>().resetUsage(),
                  child: Text(
                    'Reset',
                    style: TextStyle(fontFamily: 'Geist', 
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.glass,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Column(
              children: [
                _UsageRow(label: 'Total tokens', value: _formatInt(gemini.totalTokensUsed)),
                const SizedBox(height: 6),
                _UsageRow(label: 'Input (prompt)', value: _formatInt(gemini.promptTokensUsed)),
                const SizedBox(height: 6),
                _UsageRow(label: 'Output (response)', value: _formatInt(gemini.responseTokensUsed)),
                const SizedBox(height: 6),
                _UsageRow(label: 'Requests', value: _formatInt(gemini.aiRequestCount)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Cumulative billable tokens across coach, program builder & insights.',
            style: TextStyle(fontFamily: 'Geist', 
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

/// One label/value line in the token-usage card.
class _UsageRow extends StatelessWidget {
  const _UsageRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontFamily: 'Geist', color: AppColors.textMuted, fontSize: 12),
        ),
        Text(
          value,
          style: TextStyle(fontFamily: 'GeistMono', 
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Format an int with thousands separators (e.g. 12345 → "12,345").
String _formatInt(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

// ── Debug log viewer (tap version 5× to open) ────────────────────────────────
class _DebugLogSheet extends StatelessWidget {
  const _DebugLogSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.sm, 0),
              child: Row(
                children: [
                  Text(
                    'Debug Logs',
                    style: TextStyle(fontFamily: 'GeistMono', 
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => DebugLogBuffer.instance.clear(),
                    child: Text(
                      'Clear',
                      style: TextStyle(fontFamily: 'Geist', 
                        color: AppColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.glassBorder, height: 1),
            Expanded(
              child: ListenableBuilder(
                listenable: DebugLogBuffer.instance,
                builder: (context, _) {
                  final lines = DebugLogBuffer.instance.lines;
                  if (lines.isEmpty) {
                    return Center(
                      child: Text(
                        'No logs yet',
                        style: TextStyle(fontFamily: 'Geist', color: AppColors.textFaint, fontSize: 13),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: scrollController,
                    reverse: true,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    itemCount: lines.length,
                    itemBuilder: (context, i) {
                      final line = lines[lines.length - 1 - i];
                      final isHc = line.contains('[HC]');
                      final isReadiness = line.contains('[Readiness]');
                      final color = isHc
                          ? AppColors.secondary
                          : isReadiness
                              ? AppColors.primary
                              : AppColors.textSoft;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Text(
                          line,
                          style: TextStyle(fontFamily: 'GeistMono', fontSize: 10, color: color),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
