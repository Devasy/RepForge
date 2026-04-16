// Profile Screen - User preferences, data management, and about

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../services/workout_provider.dart';
import '../services/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

const String _appVersion = '1.0.12';
const String _createdBy = 'Devasy Patel';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isBackingUp = false;

  // ==================== Data Actions ====================

  Future<void> _exportToFile() async {
    setState(() => _isExporting = true);
    try {
      final provider = context.read<WorkoutProvider>();
      final jsonString = await provider.exportAllData();

      final tempDir = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now());
      final file = File('${tempDir.path}/repforge_backup_$dateStr.json');
      await file.writeAsString(jsonString);

      final result = await Share.shareXFiles([XFile(file.path)],
          subject: 'RepForge Backup');

      if (!mounted) return;
      if (result.status == ShareResultStatus.success ||
          result.status == ShareResultStatus.dismissed) {
        _showSnack('Backup exported successfully!', AppTheme.success);
      }
    } catch (e) {
      if (mounted) _showSnack('Export failed. Please try again.', AppTheme.error);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _importFromFile() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Import Backup',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'This will merge the backup with your existing data. '
          'Select a .json RepForge backup file to continue.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Choose File'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isImporting = true);
    try {
      final result = await FilePicker.platform
          .pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      if (result == null || result.files.single.path == null) {
        if (mounted) setState(() => _isImporting = false);
        return;
      }

      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      if (!data.containsKey('sessions') && !data.containsKey('routines')) {
        if (mounted) _showSnack('Invalid backup file.', AppTheme.error);
        return;
      }

      final provider = context.read<WorkoutProvider>();
      await provider.importData(jsonString);

      if (!mounted) return;
      final sessionCount = (data['sessions'] as List?)?.length ?? 0;
      final routineCount = (data['routines'] as List?)?.length ?? 0;
      _showSnack(
          'Import complete! $sessionCount sessions, $routineCount routines.',
          AppTheme.success);
    } catch (e) {
      if (mounted) _showSnack('Import failed. Invalid backup file.', AppTheme.error);
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _performCloudBackup() async {
    setState(() => _isBackingUp = true);
    try {
      final provider = context.read<WorkoutProvider>();
      final jsonString = await provider.exportAllData();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      final api = context.read<ApiService>();
      await api.trackEvent('backup_triggered').catchError((_) => null);
      final success = await api.backupData(data);

      if (!mounted) return;
      _showSnack(
        success ? 'Cloud backup successful!' : 'Backup failed. Please try again.',
        success ? AppTheme.success : AppTheme.error,
      );
    } catch (_) {
      if (mounted) _showSnack('Something went wrong.', AppTheme.error);
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  // ==================== Build ====================

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.md),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildPreferencesSection(settings),
                const SizedBox(height: AppSpacing.lg),
                _buildDataSection(),
                const SizedBox(height: AppSpacing.lg),
                _buildCloudSyncSection(),
                const SizedBox(height: AppSpacing.lg),
                _buildAboutSection(),
                const SizedBox(height: AppSpacing.xxl),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      backgroundColor: AppTheme.surfaceColor,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryColor, Color(0xFF8B7FE8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(
                      Icons.fitness_center,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'RepForge',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'v$_appVersion',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== Preferences ====================

  Widget _buildPreferencesSection(SettingsProvider settings) {
    return _ProfileSection(
      icon: Icons.tune_rounded,
      iconColor: AppTheme.primaryColor,
      title: 'Preferences',
      subtitle: 'Customize weight display and input steps',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingsLabel('Weight Unit'),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _UnitToggleButton(
                  label: 'kg',
                  selected: settings.weightUnit == WeightUnit.kg,
                  onTap: () => settings.setWeightUnit(WeightUnit.kg),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _UnitToggleButton(
                  label: 'lbs',
                  selected: settings.weightUnit == WeightUnit.lbs,
                  onTap: () => settings.setWeightUnit(WeightUnit.lbs),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _SettingsLabel('Weight Increment'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: settings.availableIncrements.map((inc) {
              final selected = settings.weightIncrement == inc;
              final label = inc == inc.truncateToDouble()
                  ? '${inc.toStringAsFixed(0)} ${settings.unitLabel}'
                  : '${inc.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '')} ${settings.unitLabel}';
              return ChoiceChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  settings.setWeightIncrement(inc);
                },
                selectedColor: AppTheme.primaryColor.withOpacity(0.25),
                backgroundColor: AppTheme.surfaceColor,
                labelStyle: TextStyle(
                  color:
                      selected ? AppTheme.primaryColor : AppTheme.textSecondary,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
                side: BorderSide(
                  color: selected ? AppTheme.primaryColor : Colors.transparent,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ==================== Data Management ====================

  Widget _buildDataSection() {
    return _ProfileSection(
      icon: Icons.storage_rounded,
      iconColor: AppTheme.secondaryColor,
      title: 'Data Management',
      subtitle: 'Export, import, or backup your workout data',
      child: Column(
        children: [
          _ActionTile(
            icon: Icons.upload_file_rounded,
            iconColor: AppTheme.secondaryColor,
            title: 'Export Backup',
            subtitle: 'Save a local .json backup file',
            loading: _isExporting,
            onTap: _isExporting ? null : _exportToFile,
          ),
          const _Divider(),
          _ActionTile(
            icon: Icons.download_rounded,
            iconColor: AppTheme.secondaryColor,
            title: 'Import Backup',
            subtitle: 'Merge data from a .json backup',
            loading: _isImporting,
            onTap: _isImporting ? null : _importFromFile,
          ),
          const _Divider(),
          _ActionTile(
            icon: Icons.cloud_upload_outlined,
            iconColor: AppTheme.primaryColor,
            title: 'Cloud Backup',
            subtitle: 'Sync to RepForge cloud (requires account)',
            loading: _isBackingUp,
            onTap: _isBackingUp ? null : _performCloudBackup,
          ),
        ],
      ),
    );
  }

  // ==================== Cloud Sync (placeholder) ====================

  Widget _buildCloudSyncSection() {
    return _ProfileSection(
      icon: Icons.sync_rounded,
      iconColor: AppTheme.warning,
      title: 'Cloud Sync',
      subtitle: 'Sync your data across devices',
      trailing: _ComingSoonBadge(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SettingsLabel('MongoDB Connection String'),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            enabled: false,
            decoration: InputDecoration(
              hintText: 'mongodb+srv://user:pass@cluster.mongodb.net/db',
              hintStyle: const TextStyle(
                  color: AppTheme.textMuted, fontSize: 13),
              prefixIcon: const Icon(Icons.link_rounded,
                  color: AppTheme.textMuted, size: 20),
              filled: true,
              fillColor: AppTheme.surfaceColor.withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Cloud sync with custom MongoDB will be available in a future update.',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== About ====================

  Widget _buildAboutSection() {
    return _ProfileSection(
      icon: Icons.info_outline_rounded,
      iconColor: AppTheme.textSecondary,
      title: 'About',
      subtitle: 'RepForge Workout Logger',
      child: Column(
        children: [
          _InfoTile(
            label: 'Version',
            value: _appVersion,
            icon: Icons.tag_rounded,
          ),
          const _Divider(),
          _InfoTile(
            label: 'Created by',
            value: _createdBy,
            icon: Icons.person_rounded,
          ),
          const _Divider(),
          _InfoTile(
            label: 'Platform',
            value: 'Android',
            icon: Icons.phone_android_rounded,
          ),
          const _Divider(),
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

// ==================== Reusable Widgets ====================

class _ProfileSection extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  const _ProfileSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
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
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
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
          const Divider(color: AppTheme.surfaceColor, height: 1),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _SettingsLabel extends StatelessWidget {
  final String text;
  const _SettingsLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _UnitToggleButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _UnitToggleButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor.withOpacity(0.2)
              : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color:
                  selected ? AppTheme.primaryColor : AppTheme.textSecondary,
              fontWeight:
                  selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool loading;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.loading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
      trailing: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            )
          : const Icon(
              Icons.chevron_right,
              color: AppTheme.textMuted,
            ),
      onTap: onTap,
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textMuted, size: 18),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      color: AppTheme.surfaceColor,
      height: 1,
      indent: 40,
    );
  }
}

class _ComingSoonBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.warning.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: AppTheme.warning.withOpacity(0.4),
        ),
      ),
      child: const Text(
        'Coming Soon',
        style: TextStyle(
          color: AppTheme.warning,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
