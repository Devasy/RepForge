// health_data_inspector_screen.dart — Wearable & Samsung Health diagnostics and PoC data explorer
//
// Proof-of-concept screen allowing users to inspect all data types accessible
// from Samsung Health, Galaxy Watches, and Android Health Connect.
// Includes interactive visual line charts and graphs for:
// - Respiratory Rate (bpm)
// - Skin Temperature (°C)
// - Energy Score (0–100 Galaxy AI)
// - Sleep Score (0–100 & duration)

import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../services/health_inspector_service.dart';
import '../theme/app_theme.dart';

class HealthDataInspectorScreen extends StatefulWidget {
  final HealthInspectorService? service;

  const HealthDataInspectorScreen({super.key, this.service});

  @override
  State<HealthDataInspectorScreen> createState() =>
      _HealthDataInspectorScreenState();
}

class _HealthDataInspectorScreenState extends State<HealthDataInspectorScreen> {
  late final HealthInspectorService _inspectorService;
  HealthInspectorInventory? _inventory;
  bool _isLoading = true;
  int _currentTab = 0; // 0: Graphs & Trends, 1: Records Inventory, 2: Diagnostics
  String _filterCategory = 'All';
  bool _enableDemoTrends = false;
  bool _skinTempUseIntraday = false;

  @override
  void initState() {
    super.initState();
    _inspectorService = widget.service ?? HealthInspectorService();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final inv = await _inspectorService.inspectHealthData();
      if (mounted) {
        setState(() {
          _inventory = inv;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading health data: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _requestPermissions() async {
    final granted = await _inspectorService.requestAllDiscoveryPermissions();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            granted
                ? 'Permissions updated! Refreshing data...'
                : 'Permissions unchanged. Check Health Connect app settings.',
          ),
          backgroundColor: granted ? AppColors.success : AppColors.warning,
        ),
      );
      await _loadData();
    }
  }

  Future<void> _requestDirectSamsungPermissions() async {
    try {
      final granted =
          await _inspectorService.requestDirectSamsungHealthPermissions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              granted.isNotEmpty
                  ? 'S-Health Direct Permissions Granted: ${granted.map((p) => p.split('.').last).join(', ')}'
                  : 'Samsung Health permission dialog closed. If it did not appear, verify Developer Mode is ON in Samsung Health.',
            ),
            backgroundColor:
                granted.isNotEmpty ? AppColors.success : AppColors.warning,
          ),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error requesting Samsung Health direct permissions: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _exportJson() async {
    if (_inventory == null) return;
    final jsonStr =
        const JsonEncoder.withIndent('  ').convert(_inventory!.toJson());
    // ignore: deprecated_member_use
    await Share.share(
      jsonStr,
      subject: 'RepForge Health Data Inventory',
    );
  }

  void _copyToClipboard() {
    if (_inventory == null) return;
    final jsonStr =
        const JsonEncoder.withIndent('  ').convert(_inventory!.toJson());
    Clipboard.setData(ClipboardData(text: jsonStr));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Diagnostics JSON copied to clipboard!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  List<HealthTimeSeriesPoint> _getEffectiveSeries(
    List<HealthTimeSeriesPoint> liveSeries,
    String metricType,
  ) {
    if (liveSeries.length >= 2) return liveSeries;
    if (!_enableDemoTrends && liveSeries.isNotEmpty) return liveSeries;
    if (!_enableDemoTrends && liveSeries.isEmpty) return [];

    // Generate realistic multi-day curve anchored to live reading if present
    final now = DateTime.now();
    switch (metricType) {
      case 'respRate':
        final base = liveSeries.isNotEmpty ? liveSeries.first.value : 14.8;
        final deltas = [0.4, -0.6, 0.2, 0.5, -0.3, 0.1, 0.0];
        return List.generate(7, (i) {
          final bpm = base + deltas[i];
          final val = double.parse(bpm.toStringAsFixed(1));
          return HealthTimeSeriesPoint(
            timestamp: now.subtract(Duration(days: 6 - i)),
            value: val,
            label: '$val breaths/min',
            extra: {'isDemo': true},
          );
        });

      case 'skinTemp':
        final base = liveSeries.isNotEmpty ? liveSeries.first.value : 34.9;
        final deltas = [-0.2, 0.3, 0.1, -0.4, 0.2, -0.1, 0.0];
        return List.generate(7, (i) {
          final t = base + deltas[i];
          final val = double.parse(t.toStringAsFixed(1));
          return HealthTimeSeriesPoint(
            timestamp: now.subtract(Duration(days: 6 - i)),
            value: val,
            minValue: val - 0.5,
            maxValue: val + 0.6,
            label: '$val °C',
            extra: {'isDemo': true},
          );
        });

      case 'energy':
        final base = liveSeries.isNotEmpty ? liveSeries.first.value : 80.0;
        final deltas = [-4.0, 3.0, -1.0, 5.0, -3.0, 2.0, 0.0];
        return List.generate(7, (i) {
          final score = (base + deltas[i]).clamp(45.0, 99.0);
          return HealthTimeSeriesPoint(
            timestamp: now.subtract(Duration(days: 6 - i)),
            value: score,
            label: '${score.round()} / 100',
            extra: {'isDemo': true},
          );
        });

      case 'sleep':
        final base = liveSeries.isNotEmpty ? liveSeries.first.value : 82.0;
        final deltas = [2.0, -5.0, 4.0, -1.0, 6.0, -3.0, 0.0];
        final durations = [440, 410, 475, 430, 490, 420, 465]; // minutes
        return List.generate(7, (i) {
          final score = (base + deltas[i]).clamp(50.0, 98.0);
          final d = durations[i];
          return HealthTimeSeriesPoint(
            timestamp: now.subtract(Duration(days: 6 - i)),
            value: score,
            label: '${score.round()} / 100 (${d ~/ 60}h ${d % 60}m)',
            extra: {'isDemo': true, 'durationMinutes': d},
          );
        });

      default:
        return liveSeries;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Wearable & Health Inspector',
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'Samsung Health · Galaxy Watch · Health Connect PoC',
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded, color: AppColors.textSoft),
            tooltip: 'Copy JSON Diagnostics',
            onPressed: _inventory == null ? null : _copyToClipboard,
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded, color: AppColors.textSoft),
            tooltip: 'Export JSON',
            onPressed: _inventory == null ? null : _exportJson,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            tooltip: 'Refresh live data',
            onPressed: _isLoading ? null : _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: AppSpacing.md),
                  Text(
                    'Querying Samsung Health & Health Connect...',
                    style: TextStyle(
                      fontFamily: 'Geist',
                      color: AppColors.textSoft,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  _buildDeviceStatusCard(),
                  const SizedBox(height: AppSpacing.sm),
                  _buildPillTabBar(),
                  const SizedBox(height: AppSpacing.md),
                  if (_currentTab == 0) ...[
                    _buildGraphsView(),
                  ] else if (_currentTab == 1) ...[
                    _buildStatsRow(),
                    const SizedBox(height: AppSpacing.md),
                    _buildCategoryFilterChips(),
                    const SizedBox(height: AppSpacing.md),
                    _buildRecordsList(),
                  ] else ...[
                    _buildDiagnosticsView(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildPillTabBar() {
    final recordCount = _inventory?.items.length ?? 0;
    final tabs = [
      '📈 Graphs (4)',
      '📋 Records ($recordCount)',
      '⚙️ Diagnostics',
    ];

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = i == _currentTab;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _currentTab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  tabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: active ? AppColors.background : AppColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDeviceStatusCard() {
    final inv = _inventory;
    final shealth = inv?.samsungHealthInfo;
    final isShealthInstalled = shealth?.isInstalled ?? false;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.glassBorder),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isShealthInstalled
                      ? const Color(0xFF0381FE).withValues(alpha: 0.15)
                      : AppColors.cardHigh,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.watch_rounded,
                  color: isShealthInstalled
                      ? const Color(0xFF0381FE)
                      : AppColors.textMuted,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Samsung Health',
                          style: TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isShealthInstalled
                                ? AppColors.success.withValues(alpha: 0.2)
                                : AppColors.cardHigh,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isShealthInstalled
                                ? 'INSTALLED (v${shealth?.versionName})'
                                : 'NOT DETECTED',
                            style: TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isShealthInstalled
                                  ? AppColors.success
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      inv?.isHealthConnectAvailable == true
                          ? 'Health Connect: Synced & Active'
                          : 'Health Connect: Not available or restricted',
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 11,
                        color: inv?.isHealthConnectAvailable == true
                            ? const Color(0xFF00BFA5)
                            : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.vpn_key_outlined, size: 14),
                label: const Text(
                  'Health Connect Perms',
                  style: TextStyle(fontFamily: 'Geist', fontSize: 11),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                onPressed: _requestPermissions,
              ),
              if (isShealthInstalled) ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.flash_on_rounded, size: 14),
                  label: const Text(
                    'Direct S-Health Perms',
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0381FE),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  onPressed: _requestDirectSamsungPermissions,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text(
                    'Open S-Health',
                    style: TextStyle(fontFamily: 'Geist', fontSize: 11),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0381FE),
                    side: const BorderSide(color: Color(0xFF0381FE)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  onPressed: () => _inspectorService.launchSamsungHealth(),
                ),
              ],
            ],
          ),
          if (inv?.directSamsungPermissions.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0381FE).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: const Color(0xFF0381FE).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, color: Color(0xFF0381FE), size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Direct SDK Active: ${inv!.directSamsungPermissions.map((p) => p.split('.').last).join(', ')}',
                      style: const TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 11,
                        color: Color(0xFF0381FE),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 0: 4 REQUESTED GRAPHS & LINE CHARTS
  // =========================================================================

  Widget _buildGraphsView() {
    final inv = _inventory;
    if (inv == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Demo Simulation Switch Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            children: [
              Icon(
                Icons.auto_graph_rounded,
                size: 18,
                color: _enableDemoTrends ? AppColors.warning : AppColors.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Multi-Day Preview Mode',
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      _enableDemoTrends
                          ? 'Showing 7-day trend preview for metrics with sparse logs'
                          : 'Showing strictly synced device recordings',
                      style: const TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _enableDemoTrends,
                activeThumbColor: AppColors.warning,
                onChanged: (val) => setState(() => _enableDemoTrends = val),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // 1. Respiratory Rate Graph
        _buildRespiratoryRateCard(inv),

        // 2. Skin Temperature Graph
        _buildSkinTempCard(inv),

        // 3. Samsung Energy Score Line Chart
        _buildEnergyScoreCard(inv),

        // 4. Samsung Sleep Score Line Chart
        _buildSleepScoreCard(inv),
      ],
    );
  }

  Widget _buildRespiratoryRateCard(HealthInspectorInventory inv) {
    final series = _getEffectiveSeries(inv.respiratoryRateSeries, 'respRate');

    return _buildMetricChartCard(
      title: 'Respiratory Rate',
      subtitle: 'Resting & nocturnal breaths per minute (bpm)',
      icon: Icons.air_rounded,
      color: const Color(0xFF00E5FF),
      series: series,
      unit: 'bpm',
      minY: 8.0,
      maxY: 28.0,
      emptyHint:
          'No respiratory rate samples found in Health Connect.\nWear Galaxy Watch during sleep to record breathing frequency.',
      guideLines: [
        HorizontalLine(
          y: 20,
          color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
          strokeWidth: 1,
          dashArray: [4, 4],
          label: HorizontalLineLabel(
            show: true,
            alignment: Alignment.topRight,
            style: const TextStyle(
              fontFamily: 'GeistMono',
              fontSize: 9,
              color: Color(0xFF00E5FF),
            ),
            labelResolver: (_) => 'NORMAL MAX (20 bpm)',
          ),
        ),
        HorizontalLine(
          y: 12,
          color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
          strokeWidth: 1,
          dashArray: [4, 4],
          label: HorizontalLineLabel(
            show: true,
            alignment: Alignment.bottomRight,
            style: const TextStyle(
              fontFamily: 'GeistMono',
              fontSize: 9,
              color: Color(0xFF00E5FF),
            ),
            labelResolver: (_) => 'NORMAL MIN (12 bpm)',
          ),
        ),
      ],
      bottomContent: const Text(
        'Normal healthy adult resting respiration: 12–20 breaths/min. Monitored overnight to detect breathing disturbances.',
        style: TextStyle(
          fontFamily: 'Geist',
          fontSize: 10,
          color: AppColors.textMuted,
          height: 1.3,
        ),
      ),
    );
  }

  Widget _buildSkinTempCard(HealthInspectorInventory inv) {
    final hasIntraday = inv.skinTempIntradaySeries.length >= 3;
    final series = _skinTempUseIntraday && hasIntraday
        ? _getEffectiveSeries(inv.skinTempIntradaySeries, 'skinTemp')
        : _getEffectiveSeries(inv.skinTempSeries, 'skinTemp');

    return _buildMetricChartCard(
      title: 'Skin Temperature',
      subtitle: 'Overnight surface temperature baseline & continuous curve',
      icon: Icons.thermostat_rounded,
      color: const Color(0xFFFF7A00),
      series: series,
      unit: '°C',
      minY: 32.0,
      maxY: 38.0,
      topTrailing: hasIntraday
          ? Row(
              children: [
                ChoiceChip(
                  label: const Text('Daily Baseline', style: TextStyle(fontSize: 10)),
                  selected: !_skinTempUseIntraday,
                  onSelected: (s) => setState(() => _skinTempUseIntraday = false),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Continuous Overnight Curve', style: TextStyle(fontSize: 10)),
                  selected: _skinTempUseIntraday,
                  onSelected: (s) => setState(() => _skinTempUseIntraday = true),
                ),
              ],
            )
          : null,
      emptyHint:
          'No skin temperature records synced from Galaxy Watch.\nRequires Galaxy Watch 5/6/7 / Galaxy Ring infrared sensor during sleep.',
      guideLines: [
        HorizontalLine(
          y: 35.0,
          color: const Color(0xFFFF7A00).withValues(alpha: 0.45),
          strokeWidth: 1,
          dashArray: [5, 4],
          label: HorizontalLineLabel(
            show: true,
            alignment: Alignment.topRight,
            style: const TextStyle(
              fontFamily: 'GeistMono',
              fontSize: 9,
              color: Color(0xFFFF7A00),
            ),
            labelResolver: (_) => 'BASELINE 35.0°C',
          ),
        ),
      ],
      bottomContent: const Text(
        'Monitored by Galaxy Watch infrared temperature sensor during sleep. Nocturnal temperature spikes often signal systemic inflammation or oncoming illness.',
        style: TextStyle(
          fontFamily: 'Geist',
          fontSize: 10,
          color: AppColors.textMuted,
          height: 1.3,
        ),
      ),
    );
  }

  Widget _buildEnergyScoreCard(HealthInspectorInventory inv) {
    final series = _getEffectiveSeries(inv.energyScoreSeries, 'energy');

    return _buildMetricChartCard(
      title: 'Samsung Energy Score',
      subtitle: 'Galaxy AI composite readiness benchmark (0–100)',
      icon: Icons.bolt_rounded,
      color: AppColors.primary,
      series: series,
      unit: 'score',
      minY: 40.0,
      maxY: 100.0,
      emptyHint:
          'No Galaxy AI Energy Score logged on device yet.\nCheck the Samsung Health Home tab for your daily Energy Score.',
      guideLines: [
        HorizontalLine(
          y: 80,
          color: AppColors.success.withValues(alpha: 0.5),
          strokeWidth: 1,
          dashArray: [5, 4],
          label: HorizontalLineLabel(
            show: true,
            alignment: Alignment.topRight,
            style: const TextStyle(
              fontFamily: 'GeistMono',
              fontSize: 9,
              color: AppColors.success,
            ),
            labelResolver: (_) => 'OPTIMAL (80+)',
          ),
        ),
        HorizontalLine(
          y: 70,
          color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
          strokeWidth: 1,
          dashArray: [5, 4],
          label: HorizontalLineLabel(
            show: true,
            alignment: Alignment.topRight,
            style: const TextStyle(
              fontFamily: 'GeistMono',
              fontSize: 9,
              color: Color(0xFF00E5FF),
            ),
            labelResolver: (_) => 'GOOD (70+)',
          ),
        ),
      ],
      bottomContent: const Text(
        'Galaxy AI synthesizes sleep duration, resting heart rate, heart rate variability (HRV), and previous-day activity to calculate this overall recovery score.',
        style: TextStyle(
          fontFamily: 'Geist',
          fontSize: 10,
          color: AppColors.textMuted,
          height: 1.3,
        ),
      ),
    );
  }

  Widget _buildSleepScoreCard(HealthInspectorInventory inv) {
    final series = _getEffectiveSeries(inv.sleepScoreSeries, 'sleep');

    return _buildMetricChartCard(
      title: 'Samsung Sleep Score',
      subtitle: 'Nightly sleep quality index (0–100) & duration',
      icon: Icons.bedtime_rounded,
      color: const Color(0xFF8B5CF6),
      series: series,
      unit: 'score',
      minY: 40.0,
      maxY: 100.0,
      emptyHint:
          'No sleep score records found.\nWear your Galaxy Watch overnight to track sleep stages and score.',
      guideLines: [
        HorizontalLine(
          y: 85,
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.55),
          strokeWidth: 1,
          dashArray: [5, 4],
          label: HorizontalLineLabel(
            show: true,
            alignment: Alignment.topRight,
            style: const TextStyle(
              fontFamily: 'GeistMono',
              fontSize: 9,
              color: Color(0xFF8B5CF6),
            ),
            labelResolver: (_) => 'EXCELLENT (85+)',
          ),
        ),
        HorizontalLine(
          y: 70,
          color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
          strokeWidth: 1,
          dashArray: [5, 4],
          label: HorizontalLineLabel(
            show: true,
            alignment: Alignment.topRight,
            style: const TextStyle(
              fontFamily: 'GeistMono',
              fontSize: 9,
              color: Color(0xFF00E5FF),
            ),
            labelResolver: (_) => 'GOOD (70+)',
          ),
        ),
      ],
      bottomContent: const Text(
        'Evaluates deep restorative sleep, REM stages, consistency, and restlessness. A score of 70+ indicates adequate physical recovery for training.',
        style: TextStyle(
          fontFamily: 'Geist',
          fontSize: 10,
          color: AppColors.textMuted,
          height: 1.3,
        ),
      ),
    );
  }

  Widget _buildMetricChartCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<HealthTimeSeriesPoint> series,
    required String unit,
    double? minY,
    double? maxY,
    List<HorizontalLine>? guideLines,
    Widget? topTrailing,
    Widget? bottomContent,
    String? emptyHint,
  }) {
    final isDemo = series.isNotEmpty && series.any((p) => p.extra['isDemo'] == true);
    final latestPoint = series.isNotEmpty ? series.last : null;

    double? minVal;
    double? maxVal;
    double? avgVal;
    if (series.isNotEmpty) {
      minVal = series.map((p) => p.value).reduce((a, b) => a < b ? a : b);
      maxVal = series.map((p) => p.value).reduce((a, b) => a > b ? a : b);
      avgVal = series.map((p) => p.value).reduce((a, b) => a + b) / series.length;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isDemo) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              'DEMO PREVIEW',
                              style: TextStyle(
                                fontFamily: 'Geist',
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ] else if (series.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              'LIVE SYNCED',
                              style: TextStyle(
                                fontFamily: 'Geist',
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (latestPoint != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      latestPoint.label ?? '${latestPoint.value.toStringAsFixed(1)} $unit',
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    Text(
                      DateFormat('MMM d, h:mm a').format(latestPoint.timestamp),
                      style: const TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (topTrailing != null) ...[
            const SizedBox(height: 8),
            topTrailing,
          ],
          const SizedBox(height: AppSpacing.md),

          // Chart or Fallback State
          if (series.isEmpty) ...[
            Container(
              height: 120,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.glassBorder),
              ),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.show_chart_rounded,
                    size: 32,
                    color: AppColors.textMuted.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    emptyHint ?? 'No records logged on device yet.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 11,
                      color: AppColors.textSoft,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (series.length == 1) ...[
            // Single point representation
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Recorded Reading: ${latestPoint!.label ?? "${latestPoint.value} $unit"}',
                          style: const TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Recorded on ${DateFormat('MMM d, y · h:mm a').format(latestPoint.timestamp)} (1 measurement on file. Turn on "Multi-Day Preview" above to see the curve preview).',
                          style: const TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Full Line Chart
            SizedBox(
              height: 175,
              child: _buildFlLineChart(
                series: series,
                color: color,
                unit: unit,
                minY: minY,
                maxY: maxY,
                guideLines: guideLines,
              ),
            ),
            const SizedBox(height: 12),
            // Stats Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMiniStat('Min', '${minVal!.toStringAsFixed(1)} $unit', color),
                _buildMiniStat('Avg', '${avgVal!.toStringAsFixed(1)} $unit', color),
                _buildMiniStat('Max', '${maxVal!.toStringAsFixed(1)} $unit', color),
                _buildMiniStat('Readings', '${series.length}', AppColors.textPrimary),
              ],
            ),
          ],

          if (bottomContent != null) ...[
            const SizedBox(height: 10),
            bottomContent,
          ],
        ],
      ),
    );
  }

  Widget _buildFlLineChart({
    required List<HealthTimeSeriesPoint> series,
    required Color color,
    required String unit,
    double? minY,
    double? maxY,
    List<HorizontalLine>? guideLines,
  }) {
    final spots = <FlSpot>[];
    for (var i = 0; i < series.length; i++) {
      spots.add(FlSpot(i.toDouble(), series[i].value));
    }

    final values = series.map((p) => p.value).toList();
    final dataMin = values.reduce((a, b) => a < b ? a : b);
    final dataMax = values.reduce((a, b) => a > b ? a : b);
    final range = dataMax - dataMin;
    final padding = range > 0 ? range * 0.15 : (dataMax * 0.1).clamp(1.0, 10.0);

    final calculatedMinY = minY ?? (dataMin - padding);
    final calculatedMaxY = maxY ?? (dataMax + padding);

    return LineChart(
      LineChartData(
        backgroundColor: Colors.transparent,
        minX: 0,
        maxX: (series.length - 1).toDouble(),
        minY: calculatedMinY,
        maxY: calculatedMaxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: AppColors.glassBorder, strokeWidth: 1),
        ),
        extraLinesData:
            guideLines != null ? ExtraLinesData(horizontalLines: guideLines) : null,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.cardHigh,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final i = spot.x.toInt();
                if (i < 0 || i >= series.length) return null;
                final point = series[i];
                final dateStr = DateFormat('MMM d, h:mm a').format(point.timestamp);
                final valStr = point.label ?? '${point.value.toStringAsFixed(1)} $unit';
                return LineTooltipItem(
                  '$valStr\n',
                  TextStyle(
                    fontFamily: 'GeistMono',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                  children: [
                    TextSpan(
                      text: dateStr,
                      style: const TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 10,
                        fontWeight: FontWeight.normal,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              getTitlesWidget: (v, _) => Text(
                v.toStringAsFixed(v >= 100 ? 0 : (v == v.roundToDouble() ? 0 : 1)),
                style: const TextStyle(
                  fontFamily: 'GeistMono',
                  fontSize: 9,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: (series.length > 7 ? (series.length / 4).ceilToDouble() : 1),
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= series.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    DateFormat('d/M').format(series[i].timestamp),
                    style: const TextStyle(
                      fontFamily: 'GeistMono',
                      fontSize: 9,
                      color: AppColors.textMuted,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: color,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: series.length <= 15,
              getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                radius: 3.5,
                color: color,
                strokeWidth: 1.5,
                strokeColor: AppColors.card,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.28),
                  color.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String val, Color color) {
    return Column(
      children: [
        Text(
          val,
          style: TextStyle(
            fontFamily: 'GeistMono',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Geist',
            fontSize: 10,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 1: RAW RECORDS LIST
  // =========================================================================

  Widget _buildStatsRow() {
    final inv = _inventory;
    final totalRecords = inv?.items.length ?? 0;
    final sHealthCount = inv?.samsungHealthCount ?? 0;
    final grantedCount =
        inv?.permissionStatus.values.where((v) => v).length ?? 0;
    final totalPerms = inv?.permissionStatus.length ?? 0;

    return Row(
      children: [
        _buildStatTile(
          'Total Types Found',
          '$totalRecords',
          Icons.category_outlined,
          AppColors.primary,
        ),
        const SizedBox(width: AppSpacing.sm),
        _buildStatTile(
          'Samsung Health Source',
          '$sHealthCount',
          Icons.bolt_rounded,
          const Color(0xFF0381FE),
        ),
        const SizedBox(width: AppSpacing.sm),
        _buildStatTile(
          'Permissions',
          '$grantedCount / $totalPerms',
          Icons.verified_user_outlined,
          const Color(0xFF00BFA5),
        ),
      ],
    );
  }

  Widget _buildStatTile(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Geist',
                fontSize: 11,
                color: AppColors.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilterChips() {
    final categories = [
      'All',
      'Body Composition (BIA Direct)',
      'Vitals & Cardiac (Direct)',
      'Vitals & Thermal (Direct)',
      'Sleep & Recovery (Direct)',
      'Activity',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: categories.map((cat) {
          final isSelected = _filterCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(
                cat,
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? AppColors.background : AppColors.textSoft,
                ),
              ),
              selected: isSelected,
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.card,
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.glassBorder,
              ),
              onSelected: (sel) {
                if (sel) setState(() => _filterCategory = cat);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecordsList() {
    final inv = _inventory;
    if (inv == null || inv.items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'No Health Records Found',
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Ensure Health Connect and Samsung Health permissions are granted above,\n'
              'and that your Galaxy Watch has synced recent metrics.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 12,
                color: AppColors.textSoft,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: _requestPermissions,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.background,
              ),
              child: const Text('Grant Health Connect Permissions'),
            ),
          ],
        ),
      );
    }

    final filteredItems = _filterCategory == 'All'
        ? inv.items
        : inv.items.where((i) => i.category == _filterCategory).toList();

    if (filteredItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        alignment: Alignment.center,
        child: Text(
          'No records found for category "$_filterCategory".',
          style: const TextStyle(
            fontFamily: 'Geist',
            color: AppColors.textMuted,
          ),
        ),
      );
    }

    return Column(
      children: filteredItems.map((item) => _buildRecordCard(item)).toList(),
    );
  }

  Widget _buildRecordCard(HealthRecordItem item) {
    final dateFormat = DateFormat('MMM d, h:mm a');
    final isSHealth = item.isFromSamsungHealth;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isSHealth
              ? const Color(0xFF0381FE).withValues(alpha: 0.4)
              : AppColors.glassBorder,
        ),
      ),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 4,
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSHealth
                  ? const Color(0xFF0381FE).withValues(alpha: 0.15)
                  : AppColors.cardHigh,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              _getCategoryIcon(item.category),
              color: isSHealth ? const Color(0xFF0381FE) : AppColors.primary,
              size: 20,
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: const TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                item.valueFormatted,
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color:
                      isSHealth ? const Color(0xFF0381FE) : AppColors.secondary,
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSHealth
                      ? const Color(0xFF0381FE).withValues(alpha: 0.2)
                      : AppColors.cardHigh,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSHealth) ...[
                        const Icon(
                          Icons.bolt_rounded,
                          size: 11,
                          color: Color(0xFF0381FE),
                        ),
                        const SizedBox(width: 2),
                      ],
                      Text(
                        item.metadata['directSdk'] == true
                            ? 'Samsung Health (Direct SDK)'
                            : item.sourceDisplayName,
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isSHealth
                              ? const Color(0xFF0381FE)
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dateFormat.format(item.timestamp),
                    style: const TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              color: AppColors.background.withValues(alpha: 0.5),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Category: ${item.category}',
                    style: const TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 12,
                      color: AppColors.textSoft,
                    ),
                  ),
                  Text(
                    'Package: ${item.sourcePackage ?? "unknown"}',
                    style: const TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 12,
                      color: AppColors.textSoft,
                    ),
                  ),
                  Text(
                    'Exact Timestamp: ${item.timestamp.toIso8601String()}',
                    style: const TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 12,
                      color: AppColors.textSoft,
                    ),
                  ),
                  if (item.metadata.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Metadata:',
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      const JsonEncoder.withIndent('  ').convert(item.metadata),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    if (category.contains('Body Composition') || category.contains('BIA')) {
      return Icons.accessibility_new_rounded;
    } else if (category.contains('Cardiac') || category.contains('Heart') || category.contains('Blood')) {
      return Icons.favorite_rounded;
    } else if (category.contains('Thermal') || category.contains('Temperature')) {
      return Icons.thermostat_rounded;
    } else if (category.contains('Sleep') || category.contains('Recovery')) {
      return Icons.bedtime_rounded;
    } else if (category.contains('Energy')) {
      return Icons.bolt_rounded;
    } else if (category.contains('Activity') || category.contains('Exercise')) {
      return Icons.directions_run_rounded;
    }
    return Icons.health_and_safety_rounded;
  }

  // =========================================================================
  // TAB 2: DIAGNOSTICS & DEVELOPER GUIDE
  // =========================================================================

  Widget _buildDiagnosticsView() {
    final inv = _inventory;
    final shealth = inv?.samsungHealthInfo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Developer Guide
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.terminal_rounded, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Samsung Health Developer Mode Guide',
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '1. Open the Samsung Health app on your phone.\n'
                '2. Tap 3 dots (or gear icon) → Settings → "About Samsung Health".\n'
                '3. Tap the version number 10 times until "Developer Mode" is unlocked.\n'
                '4. In Developer Mode, allow external apps to read data.\n'
                '5. Tap "Direct S-Health Perms" at the top of this screen to approve access scopes.',
                style: TextStyle(
                  fontFamily: 'Geist',
                  color: AppColors.textSoft,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.settings_outlined, size: 14),
                label: const Text('Open S-Health App Info Settings', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF0381FE)),
                onPressed: () => _inspectorService.openSamsungHealthSettings(),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // App Signatures & Credentials
        if (shealth != null && shealth.appSha256Fingerprint.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RepForge App Identity (for Samsung Partner Portal)',
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  'Package: ${shealth.appPackageName}\n'
                  'SHA-256: ${shealth.appSha256Fingerprint}',
                  style: const TextStyle(
                    fontFamily: 'GeistMono',
                    fontSize: 11,
                    color: AppColors.cyan,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // Direct SDK Errors (if any)
        if (inv?.directSamsungErrors.isNotEmpty == true) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Direct SDK Diagnostic Logs',
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontWeight: FontWeight.w700,
                        color: AppColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ...inv!.directSamsungErrors.entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        '• ${e.key}: ${e.value}',
                        style: const TextStyle(
                          fontFamily: 'GeistMono',
                          fontSize: 11,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // Quick Export Actions
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy Diagnostics JSON'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cardHigh,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _copyToClipboard,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.share_rounded, size: 16),
                label: const Text('Export JSON'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _exportJson,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
