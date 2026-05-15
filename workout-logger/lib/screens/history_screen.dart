// history_screen.dart — Workout history with calendar + session list

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/models.dart';
import '../services/workout_provider.dart';
import '../services/managers/history_manager.dart';
import '../services/settings_provider.dart';
import '../theme/app_theme.dart';
import 'edit_workout_session_screen.dart';
import 'widgets/rf_widgets.dart';
import 'widgets/session_details_sheet.dart';
import 'widgets/calendar_grid.dart';

const Color _hcColor = Color(0xFF4ECDC4);

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _showSearch = false;

  // Calendar state
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  int? _selectedDay;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<WorkoutSession> _filtered(List<WorkoutSession> sessions, WorkoutProvider provider) {
    if (_query.isEmpty) return sessions;
    final q = _query.toLowerCase();
    return sessions.where((s) {
      final dateStr = DateFormat('EEEE MMM d yyyy').format(s.date).toLowerCase();
      if (dateStr.contains(q)) return true;
      return s.exercises.any((e) {
        final name = provider.getExerciseName(e.exerciseId).toLowerCase();
        return name.contains(q);
      });
    }).toList();
  }

  Map<String, List<WorkoutSession>> _group(List<WorkoutSession> sessions) {
    final map = <String, List<WorkoutSession>>{};
    for (final s in sessions) {
      final key = DateFormat('MMMM yyyy').format(s.date);
      map.putIfAbsent(key, () => []).add(s);
    }
    return map;
  }

  Map<int, CalendarDayData> _buildCalendarData(List<WorkoutSession> sessions) {
    final map = <int, CalendarDayData>{};
    final monthSessions = sessions.where((s) =>
        s.date.year == _calendarMonth.year && s.date.month == _calendarMonth.month);
    for (final s in monthSessions) {
      final vol = s.totalVolume;
      final intensity = vol > 15000 ? 3 : vol > 5000 ? 2 : 1;
      map[s.date.day] = CalendarDayData(intensity: intensity);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final historyManager = context.watch<HistoryManager>();
    final provider = context.read<WorkoutProvider>();
    final settings = context.watch<SettingsProvider>();
    final all = historyManager.sessions;
    final filtered = _filtered(all, provider);
    final grouped = _group(filtered);
    final months = grouped.keys.toList();

    final totalVolume = all.fold<double>(0, (s, e) => s + e.totalVolume);
    final hasUnsynced = settings.healthConnectEnabled && all.any((s) => s.hcSyncedAt == null);

    return Stack(
      children: [
        const AmbientGlow(),
        SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: _buildHeader(context, hasUnsynced, historyManager),
                ),

                // Search bar (animated)
                if (_showSearch)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: _SearchBar(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ),
                  ),

                // Lifetime summary
                SliverToBoxAdapter(
                  child: _buildSummaryCard(all, totalVolume),
                ),

                // Calendar card
                if (_query.isEmpty)
                  SliverToBoxAdapter(
                    child: _buildCalendarCard(all),
                  ),

                // Session list
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.history_rounded, size: 48, color: AppColors.textFaint),
                          const SizedBox(height: 12),
                          Text(
                            _query.isNotEmpty ? 'No results' : 'No Workout History',
                            style: GoogleFonts.geist(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _query.isNotEmpty ? 'Try a different search term' : 'Complete a workout to see it here',
                            style: GoogleFonts.geist(fontSize: 13, color: AppColors.textFaint),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final month = months[i];
                          final sessions = grouped[month]!;
                          return _MonthGroup(
                            month: month,
                            sessions: sessions,
                            provider: provider,
                            historyManager: historyManager,
                            settings: settings,
                          );
                        },
                        childCount: months.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
  }

  Widget _buildHeader(BuildContext context, bool hasUnsynced, HistoryManager historyManager) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LOG',
                  style: GoogleFonts.geist(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textFaint,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'History',
                  style: GoogleFonts.geist(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.6,
                  ),
                ),
              ],
            ),
          ),
          if (hasUnsynced)
            GestureDetector(
              onTap: () {
                historyManager.syncAllUnsynced();
                ScaffoldMessenger.of(context).showSnackBar(
                  _snackBar('Syncing all unsynced workouts…'),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: _hcColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(color: _hcColor.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite_rounded, size: 13, color: _hcColor),
                    SizedBox(width: 5),
                    Text('Sync', style: TextStyle(color: _hcColor, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          GestureDetector(
            onTap: () => setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) {
                _query = '';
                _searchController.clear();
              }
            }),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _showSearch ? AppColors.primary.withValues(alpha: 0.15) : AppColors.glass2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _showSearch ? AppColors.primary.withValues(alpha: 0.4) : AppColors.glassBorder,
                ),
              ),
              child: Icon(
                _showSearch ? Icons.close_rounded : Icons.search_rounded,
                size: 16,
                color: _showSearch ? AppColors.primary : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(List<WorkoutSession> all, double totalVolume) {
    final volStr = totalVolume >= 1000000
        ? '${(totalVolume / 1000000).toStringAsFixed(1)}M'
        : totalVolume >= 1000
            ? '${(totalVolume / 1000).toStringAsFixed(0)}k'
            : totalVolume.toStringAsFixed(0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              _SummaryCell(label: 'WORKOUTS', value: '${all.length}', unit: 'total'),
              const _VertDivider(),
              _SummaryCell(label: 'VOLUME', value: volStr, unit: 'kg'),
              const _VertDivider(),
              _SummaryCell(label: 'THIS MONTH', value: '${all.where((s) => s.date.month == DateTime.now().month && s.date.year == DateTime.now().year).length}', unit: 'sessions'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarCard(List<WorkoutSession> sessions) {
    final monthLabel = DateFormat('MMMM yyyy').format(_calendarMonth);
    final monthSessions = sessions.where((s) =>
        s.date.year == _calendarMonth.year && s.date.month == _calendarMonth.month).length;
    final calData = _buildCalendarData(sessions);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() {
                    _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month - 1);
                    _selectedDay = null;
                  }),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.glass2,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.chevron_left_rounded, size: 18, color: AppColors.textMuted),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        monthLabel,
                        style: GoogleFonts.geist(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        '$monthSessions session${monthSessions == 1 ? '' : 's'}',
                        style: GoogleFonts.geist(fontSize: 11, color: AppColors.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    final next = DateTime(_calendarMonth.year, _calendarMonth.month + 1);
                    if (next.isBefore(DateTime.now()) || next.month == DateTime.now().month) {
                      _calendarMonth = next;
                      _selectedDay = null;
                    }
                  }),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.glass2,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CalendarMonthGrid(
              year: _calendarMonth.year,
              month: _calendarMonth.month,
              workoutDays: calData,
              selectedDay: _selectedDay,
              onDayTap: (day) => setState(() => _selectedDay = _selectedDay == day ? null : day),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Summary cell ───────────────────────────────────────────────────────────────

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({required this.label, required this.value, required this.unit});
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.geist(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppColors.textFaint,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.geistMono(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            unit,
            style: GoogleFonts.geist(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  const _VertDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, color: AppColors.glassBorder);
  }
}

// ── Search bar ─────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.glass2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        autofocus: true,
        style: GoogleFonts.geist(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search by date or exercise…',
          hintStyle: GoogleFonts.geist(color: AppColors.textMuted, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

// ── Month group ────────────────────────────────────────────────────────────────

class _MonthGroup extends StatelessWidget {
  const _MonthGroup({
    required this.month,
    required this.sessions,
    required this.provider,
    required this.historyManager,
    required this.settings,
  });
  final String month;
  final List<WorkoutSession> sessions;
  final WorkoutProvider provider;
  final HistoryManager historyManager;
  final SettingsProvider settings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 10),
          child: Row(
            children: [
              Text(
                month,
                style: GoogleFonts.geist(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSoft,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Container(height: 1, color: AppColors.glassBorder)),
              const SizedBox(width: 10),
              Text(
                '${sessions.length}',
                style: GoogleFonts.geistMono(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        ...sessions.map(
          (s) => _HistoryCard(
            session: s,
            provider: provider,
            historyManager: historyManager,
            showSync: settings.healthConnectEnabled && s.hcSyncedAt == null,
          ),
        ),
      ],
    );
  }
}

// ── Per-session card ────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.session,
    required this.provider,
    required this.historyManager,
    required this.showSync,
  });

  final WorkoutSession session;
  final WorkoutProvider provider;
  final HistoryManager historyManager;
  final bool showSync;

  void _openDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, sc) => SessionDetailsSheet(
          session: session,
          provider: provider,
          scrollController: sc,
          onEdit: () {
            Navigator.of(ctx).pop();
            Navigator.of(context).push<bool>(
              MaterialPageRoute(builder: (_) => EditWorkoutSessionScreen(session: session)),
            );
          },
          onDelete: () => _confirmDelete(ctx),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('Delete Workout?', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Delete workout from ${DateFormat('MMMM d, yyyy').format(session.date)}? This cannot be undone.',
          style: const TextStyle(color: AppColors.textSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSoft)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final nav = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      try {
        await provider.deleteWorkoutSession(session.id);
        if (context.mounted) {
          nav.pop();
          messenger.showSnackBar(_snackBar('Workout deleted'));
        }
      } catch (e) {
        if (context.mounted) {
          messenger.showSnackBar(_snackBar('Failed to delete workout', isError: true));
        }
      }
    }
  }

  void _handleMenu(BuildContext context, String value) {
    if (value == 'edit') {
      Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => EditWorkoutSessionScreen(session: session)),
      );
    } else if (value == 'sync') {
      historyManager.syncSession(session);
      ScaffoldMessenger.of(context).showSnackBar(_snackBar('Syncing to Health Connect…'));
    } else if (value == 'delete') {
      _confirmDelete(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayAbbr = DateFormat('EEE').format(session.date);
    final dayNum = session.date.day;
    final exCount = session.exercises.length;
    final setCount = session.exercises.fold(0, (s, e) => s + e.sets.length);
    final vol = session.totalVolume;
    final volStr = vol >= 1000 ? '${(vol / 1000).toStringAsFixed(1)}k' : vol.toStringAsFixed(0);
    final duration = session.duration;
    final routineName = session.routineId != null
        ? provider.routines.cast<Routine?>().firstWhere(
            (r) => r?.id == session.routineId, orElse: () => null)?.name ?? 'Workout'
        : 'Quick Workout';

    return GestureDetector(
      onTap: () => _openDetails(context),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GlassCard(
          padding: EdgeInsets.zero,
          child: Row(
            children: [
              // Date column
              Container(
                width: 56,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.glass2,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
                ),
                child: Column(
                  children: [
                    Text(
                      dayAbbr.toUpperCase(),
                      style: GoogleFonts.geist(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.6),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$dayNum',
                      style: GoogleFonts.geistMono(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
              // Vertical divider
              Container(width: 1, height: 56, color: AppColors.glassBorder),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        routineName,
                        style: GoogleFonts.geist(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$exCount exercises · $setCount sets${duration > 0 ? ' · ${duration}m' : ''}',
                        style: GoogleFonts.geist(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
              // Volume
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      volStr,
                      style: GoogleFonts.geistMono(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondary,
                      ),
                    ),
                    Text('kg', style: GoogleFonts.geist(fontSize: 10, color: AppColors.textMuted)),
                  ],
                ),
              ),
              // Menu
              PopupMenuButton<String>(
                color: AppColors.cardHigh,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted, size: 18),
                onSelected: (v) => _handleMenu(context, v),
                itemBuilder: (_) => [
                  _menuItem('edit', Icons.edit_outlined, 'Edit', AppColors.primary),
                  if (showSync)
                    _menuItem('sync', Icons.favorite_outlined, 'Sync to Health Connect', _hcColor),
                  _menuItem('delete', Icons.delete_outline, 'Delete', AppColors.error),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label, Color color) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: color, fontSize: 14)),
        ],
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

SnackBar _snackBar(String msg, {bool isError = false}) {
  return SnackBar(
    content: Text(msg, style: const TextStyle(color: AppColors.textPrimary)),
    backgroundColor: isError ? AppColors.error : AppColors.cardHigh,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
    duration: const Duration(seconds: 2),
  );
}
