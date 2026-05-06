// history_screen.dart — Workout history with month grouping and search

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/workout_provider.dart';
import '../services/managers/history_manager.dart';
import '../services/settings_provider.dart';
import '../theme/app_theme.dart';
import 'edit_workout_session_screen.dart';
import 'widgets/rf_widgets.dart';
import 'widgets/rf_cards.dart';
import 'widgets/session_details_sheet.dart';

const Color _hcColor = Color(0xFF4ECDC4);

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _searchController = TextEditingController();
  String _query = '';

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

  @override
  Widget build(BuildContext context) {
    final historyManager = context.watch<HistoryManager>();
    final provider = context.read<WorkoutProvider>();
    final settings = context.watch<SettingsProvider>();
    final all = historyManager.sessions;
    final filtered = _filtered(all, provider);
    final grouped = _group(filtered);
    final months = grouped.keys.toList();

    final hasUnsynced = settings.healthConnectEnabled &&
        all.any((s) => s.hcSyncedAt == null);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _Header(
                hasUnsynced: hasUnsynced,
                onSyncAll: () {
                  historyManager.syncAllUnsynced();
                  ScaffoldMessenger.of(context).showSnackBar(
                    _snackBar('Syncing all unsynced workouts…'),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: _SearchBar(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            ),
            if (filtered.isEmpty)
              SliverFillRemaining(
                child: _query.isNotEmpty
                    ? RFEmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No results',
                        subtitle: 'Try a different search term',
                      )
                    : RFEmptyState(
                        icon: Icons.history_rounded,
                        title: 'No Workout History',
                        subtitle: 'Complete a workout to see it here',
                      ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.xxl,
                ),
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
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({required this.hasUnsynced, required this.onSyncAll});
  final bool hasUnsynced;
  final VoidCallback onSyncAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          const Text(
            'History',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          if (hasUnsynced)
            GestureDetector(
              onTap: onSyncAll,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 6,
                ),
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
                    Text(
                      'Sync All',
                      style: TextStyle(
                        color: _hcColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: const InputDecoration(
          hintText: 'Search by date or exercise…',
          hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted, size: 18),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
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
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: RFSectionHeader(month),
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

// ── Per-session card with menu ──────────────────────────────────────────────────
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
              MaterialPageRoute(
                builder: (_) => EditWorkoutSessionScreen(session: session),
              ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text(
          'Delete Workout?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Delete workout from ${DateFormat('MMMM d, yyyy').format(session.date)}? '
          'This cannot be undone.',
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
          nav.pop(); // close sheet if open
          messenger.showSnackBar(_snackBar('Workout deleted'));
        }
      } catch (e) {
        debugPrint('Delete failed: $e');
        if (context.mounted) {
          messenger.showSnackBar(_snackBar('Failed to delete workout', isError: true));
        }
      }
    }
  }

  void _handleMenu(BuildContext context, String value) {
    if (value == 'edit') {
      Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => EditWorkoutSessionScreen(session: session),
        ),
      );
    } else if (value == 'sync') {
      historyManager.syncSession(session);
      ScaffoldMessenger.of(context).showSnackBar(
        _snackBar('Syncing to Health Connect…'),
      );
    } else if (value == 'delete') {
      _confirmDelete(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SessionCard(
      session: session,
      getExerciseName: provider.getExerciseName,
      synced: session.hcSyncedAt != null,
      onTap: () => _openDetails(context),
      trailing: PopupMenuButton<String>(
        color: AppColors.cardHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted, size: 18),
        onSelected: (v) => _handleMenu(context, v),
        itemBuilder: (_) => [
          _menuItem('edit', Icons.edit_outlined, 'Edit', AppColors.primary),
          if (showSync)
            _menuItem('sync', Icons.favorite_outlined, 'Sync to Health Connect', _hcColor),
          _menuItem('delete', Icons.delete_outline, 'Delete', AppColors.error),
        ],
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
