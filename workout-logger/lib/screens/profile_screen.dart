// profile_screen.dart — User preferences, data management, and about

import 'dart:async' show unawaited;
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
import '../services/managers/readiness_manager.dart';
import '../services/health_data_sync_service.dart';
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
  bool _isRequestingReadinessPermission = false;
  bool _isSyncingHealthData = false;
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
    if (!settings.healthConnectEnabled && !settings.readinessEnabled) return;
    try {
      final hc = context.read<IHealthConnectService>();
      final available = await hc.isAvailable();
      if (!available) {
        if (mounted) await settings.setHealthConnectEnabled(false);
        if (mounted) await settings.setReadinessEnabled(false);
        return;
      }
      if (settings.healthConnectEnabled) {
        final hasPerms = await hc.hasPermissions();
        if (!hasPerms && mounted) {
          await settings.setHealthConnectEnabled(false);
        }
      }
      if (settings.readinessEnabled) {
        final granted = await hc.grantedReadTypes();
        if (granted.isEmpty && mounted) {
          await settings.setReadinessEnabled(false);
        }
      }
    } catch (e) {
      debugPrint('HC reconciliation error: $e');
      if (mounted) await settings.setHealthConnectEnabled(false);
      if (mounted) await settings.setReadinessEnabled(false);
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

  Future<void> _requestReadinessPermission() async {
    debugPrint('[Readiness] toggle tapped — starting permission flow');
    setState(() => _isRequestingReadinessPermission = true);
    try {
      final hc = context.read<IHealthConnectService>();
      final available = await hc.isAvailable();
      debugPrint('[Readiness] isAvailable = $available');
      if (!available) {
        if (mounted) {
          _showSnack(
            'Health Connect is not available on this device.',
            AppColors.error,
          );
        }
        return;
      }

      // Any single granted read type is enough — readiness components
      // degrade independently when data is missing.
      var granted = await hc.grantedReadTypes();
      debugPrint('[Readiness] granted before request = $granted');
      if (granted.isEmpty) {
        debugPrint('[Readiness] requesting read permissions…');
        try {
          await hc.requestReadPermissions();
        } catch (e) {
          debugPrint('[Readiness] requestReadPermissions threw: $e');
        }
        granted = await hc.grantedReadTypes();
        debugPrint('[Readiness] granted after request = $granted');
      }

      if (!mounted) return;
      if (granted.isNotEmpty) {
        debugPrint('[Readiness] permissions granted — enabling readiness');
        final settings = context.read<SettingsProvider>();
        await settings.setReadinessEnabled(true);
        if (!mounted) return;
        // Compute the first snapshot right away so the home card appears.
        unawaited(context.read<ReadinessManager>().refresh(force: true));
        _showSnack('Readiness insights enabled!', AppColors.success);
      } else {
        debugPrint('[Readiness] still no granted types — showing manual instructions');
        _showSnack(
          'Open Health Connect → App permissions → RepForge and allow Sleep and Heart rate.',
          AppColors.warning,
        );
      }
    } catch (e) {
      debugPrint('[Readiness] unexpected error: $e');
      if (mounted) {
        _showSnack('Could not connect to Health Connect.', AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _isRequestingReadinessPermission = false);
    }
  }

  Future<void> _syncHealthDataNow() async {
    setState(() => _isSyncingHealthData = true);
    try {
      final sync = context.read<HealthDataSyncService?>();
      if (sync == null) {
        if (mounted) {
          _showSnack('Health data sync is not available.', AppColors.error);
        }
        return;
      }
      await sync.sync(force: true);
      if (mounted) _showSnack('Coach data synced!', AppColors.success);
    } catch (e) {
      if (mounted) _showSnack('Sync failed. Try again later.', AppColors.error);
    } finally {
      if (mounted) setState(() => _isSyncingHealthData = false);
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
        title: Text(
          'Import Backup',
          style: TextStyle(fontFamily: 'Geist', 
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'This will merge the backup with your existing data. '
          'Select a .json RepForge backup file to continue.',
          style: TextStyle(fontFamily: 'Geist', color: AppColors.textSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(fontFamily: 'Geist', color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: Text(
              'Choose File',
              style: TextStyle(fontFamily: 'Geist', fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isImporting = true);
    try {
      final result = await FilePicker.pickFiles(
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
        content: Text(
          message,
          style: TextStyle(fontFamily: 'Geist', color: AppColors.textPrimary),
        ),
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
          _buildHero(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                PreferencesSection(
                  settings: settings,
                  onHaptic: () => HapticFeedback.selectionClick(),
                ),
                const SizedBox(height: AppSpacing.md),
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
                  isReadinessLoading: _isRequestingReadinessPermission,
                  onReadinessToggle: (value) async {
                    if (value) {
                      await _requestReadinessPermission();
                    } else {
                      await settings.setReadinessEnabled(false);
                    }
                  },
                  isHealthSyncLoading: _isSyncingHealthData,
                  onHealthSyncNow: _isSyncingHealthData ? null : _syncHealthDataNow,
                ),
                const SizedBox(height: AppSpacing.md),
                DataManagementSection(
                  isExporting: _isExporting,
                  isImporting: _isImporting,
                  isBackingUp: _isBackingUp,
                  onExport: _isExporting ? null : _exportToFile,
                  onImport: _isImporting ? null : _importFromFile,
                  onCloudBackup: _isBackingUp ? null : _performCloudBackup,
                ),
                const SizedBox(height: AppSpacing.md),
                const AiSettingsSection(),
                const SizedBox(height: AppSpacing.md),
                const CloudSyncSection(),
                const SizedBox(height: AppSpacing.md),
                AboutSection(appVersion: _appVersion),
                const SizedBox(height: AppSpacing.xxl),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return SliverToBoxAdapter(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Ambient violet wash centred at top
          Positioned(
            top: -80,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.28),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.65],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Brand avatar
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, Color(0xFF5B21B6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryGlow(0.50),
                              blurRadius: 24,
                              spreadRadius: -4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.fitness_center_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const Spacer(),
                      // Version pill
                      if (_appVersion.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.glass3,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            border: Border.all(
                              color: AppColors.glassBorderStrong,
                            ),
                          ),
                          child: Text(
                            'v$_appVersion',
                            style: TextStyle(fontFamily: 'GeistMono', 
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'RepForge',
                    style: TextStyle(fontFamily: 'Geist', 
                      color: AppColors.textPrimary,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Settings & preferences',
                    style: TextStyle(fontFamily: 'Geist', 
                      color: AppColors.textMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
