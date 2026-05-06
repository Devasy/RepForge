// profile_screen.dart — User preferences, data management, and about

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/workout_provider.dart';
import '../services/settings_provider.dart';
import '../services/api_service.dart';
import '../services/interfaces/health_connect_service_interface.dart';
import '../theme/app_theme.dart';
import 'widgets/profile_sections.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver {
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isBackingUp = false;
  bool _isRequestingHcPermission = false;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _appVersion = info.version);
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _reconcileHealthConnectState(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reconcileHealthConnectState();
    }
  }

  Future<void> _reconcileHealthConnectState() async {
    if (!mounted) return;
    final settings = context.read<SettingsProvider>();
    if (!settings.healthConnectEnabled) return;
    try {
      final hc = context.read<IHealthConnectService>();
      final available = await hc.isAvailable();
      if (!available) {
        if (mounted) await settings.setHealthConnectEnabled(false);
        return;
      }
      final hasPerms = await hc.hasPermissions();
      if (!hasPerms) {
        if (mounted) await settings.setHealthConnectEnabled(false);
      }
    } catch (e) {
      debugPrint('HC reconciliation error: $e');
      if (mounted) await settings.setHealthConnectEnabled(false);
    }
  }

  Future<void> _requestHealthConnectPermission() async {
    setState(() => _isRequestingHcPermission = true);
    try {
      final hc = context.read<IHealthConnectService>();
      final available = await hc.isAvailable();
      if (!available) {
        if (mounted) {
          _showSnack(
            'Health Connect is not available on this device.',
            AppColors.error,
          );
        }
        return;
      }

      bool granted = await hc.hasPermissions();
      if (!granted) {
        try {
          granted = await hc.requestPermissions();
        } catch (_) {
          granted = await hc.hasPermissions();
        }
      }

      if (!mounted) return;
      if (granted) {
        final settings = context.read<SettingsProvider>();
        await settings.setHealthConnectEnabled(true);
        _showSnack('Health Connect connected!', AppColors.success);
      } else {
        _showSnack(
          'Open Health Connect → App permissions → RepForge and enable Exercise.',
          AppColors.warning,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Could not connect to Health Connect.', AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _isRequestingHcPermission = false);
    }
  }

  Future<void> _exportToFile() async {
    setState(() => _isExporting = true);
    try {
      final provider = context.read<WorkoutProvider>();
      final jsonString = await provider.exportAllData();
      final tempDir = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now());
      final file = File('${tempDir.path}/repforge_backup_$dateStr.json');
      await file.writeAsString(jsonString);
      // ignore: deprecated_member_use
      final result = await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'RepForge Backup',
      );
      if (!mounted) return;
      if (result.status == ShareResultStatus.success ||
          result.status == ShareResultStatus.dismissed) {
        _showSnack('Backup exported successfully!', AppColors.success);
      }
    } catch (e) {
      if (mounted) _showSnack('Export failed. Please try again.', AppColors.error);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _importFromFile() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text(
          'Import Backup',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'This will merge the backup with your existing data. '
          'Select a .json RepForge backup file to continue.',
          style: TextStyle(color: AppColors.textSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSoft),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('Choose File'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isImporting = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.single.path == null) {
        if (mounted) setState(() => _isImporting = false);
        return;
      }
      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      if (!data.containsKey('sessions') && !data.containsKey('routines')) {
        if (mounted) _showSnack('Invalid backup file.', AppColors.error);
        return;
      }
      if (!mounted) return;
      final provider = context.read<WorkoutProvider>();
      await provider.importData(jsonString);
      if (!mounted) return;
      final sessionCount = (data['sessions'] as List?)?.length ?? 0;
      final routineCount = (data['routines'] as List?)?.length ?? 0;
      _showSnack(
        'Import complete! $sessionCount sessions, $routineCount routines.',
        AppColors.success,
      );
    } catch (e) {
      if (mounted) _showSnack('Import failed. Invalid backup file.', AppColors.error);
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _performCloudBackup() async {
    setState(() => _isBackingUp = true);
    final provider = context.read<WorkoutProvider>();
    final api = context.read<ApiService>();
    try {
      final jsonString = await provider.exportAllData();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      await api.trackEvent('backup_triggered').catchError((_) => null);
      final success = await api.backupData(data);
      if (!mounted) return;
      _showSnack(
        success ? 'Cloud backup successful!' : 'Backup failed. Please try again.',
        success ? AppColors.success : AppColors.error,
      );
    } catch (_) {
      if (mounted) _showSnack('Something went wrong.', AppColors.error);
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: AppColors.textPrimary)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.md),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                PreferencesSection(
                  settings: settings,
                  onHaptic: () => HapticFeedback.selectionClick(),
                ),
                const SizedBox(height: AppSpacing.lg),
                HealthConnectSection(
                  settings: settings,
                  isLoading: _isRequestingHcPermission,
                  onToggle: (value) async {
                    if (value) {
                      await _requestHealthConnectPermission();
                    } else {
                      await settings.setHealthConnectEnabled(false);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                DataManagementSection(
                  isExporting: _isExporting,
                  isImporting: _isImporting,
                  isBackingUp: _isBackingUp,
                  onExport: _isExporting ? null : _exportToFile,
                  onImport: _isImporting ? null : _importFromFile,
                  onCloudBackup: _isBackingUp ? null : _performCloudBackup,
                ),
                const SizedBox(height: AppSpacing.lg),
                const CloudSyncSection(),
                const SizedBox(height: AppSpacing.lg),
                AboutSection(appVersion: _appVersion),
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
      backgroundColor: AppColors.surface,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, Color(0xFF8B7FE8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(
                      Icons.fitness_center_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'RepForge',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'v$_appVersion',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
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
}
