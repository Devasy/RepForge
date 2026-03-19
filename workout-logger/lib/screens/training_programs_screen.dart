// Training Programs Screen
//
// Browse, import, and manage structured training programs.
// Supports JSON import from file or clipboard.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/managers/program_manager.dart';
import '../theme/app_theme.dart';
import 'program_detail_screen.dart';

class TrainingProgramsScreen extends StatelessWidget {
  const TrainingProgramsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(),
            Expanded(child: _ProgramList()),
          ],
        ),
      ),
      floatingActionButton: _ImportFAB(),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.menu_book_rounded,
                color: AppTheme.primaryColor,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Training Programs',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Structured multi-week plans with deload weeks, progressive overload, and milestones.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          _ActiveEnrollmentCard(),
        ],
      ),
    );
  }
}

class _ActiveEnrollmentCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final manager = context.watch<ProgramManager>();
    final enrollment = manager.activeEnrollment;
    final program = manager.activeProgram;

    if (enrollment == null || program == null) return const SizedBox.shrink();

    final phase = program.phaseForWeek(enrollment.currentWeek);
    final completedCount = enrollment.completedDays.values.where((v) => v).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.15),
            AppTheme.secondaryColor.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.play_circle_filled_rounded,
                color: AppTheme.primaryColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'ACTIVE PROGRAM',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            program.name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (phase != null) ...[
            const SizedBox(height: 4),
            Text(
              'Week ${enrollment.currentWeek} · ${phase.name}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: enrollment.currentWeek / program.durationWeeks,
              backgroundColor: AppTheme.cardColor,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.primaryColor,
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Week ${enrollment.currentWeek} of ${program.durationWeeks}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                '$completedCount sessions logged',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProgramDetailScreen(program: program),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.primaryColor),
                    foregroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('View Plan'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: AppTheme.surfaceColor,
                      title: const Text('Advance to Next Week?'),
                      content: const Text(
                        'Mark this week as complete and move to the next week.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Advance'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    await context.read<ProgramManager>().advanceWeek();
                  }
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.textSecondary.withOpacity(0.4)),
                  foregroundColor: AppTheme.textSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                ),
                child: const Text('Next Week →'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgramList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final programs = context.watch<ProgramManager>().programs;

    if (programs.isEmpty) {
      return _EmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: programs.length,
      itemBuilder: (context, index) => _ProgramCard(program: programs[index]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 72,
              color: AppTheme.textSecondary.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No Training Programs',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Import a JSON training plan or paste one from clipboard.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _showImportDialog(context),
              icon: const Icon(Icons.upload_rounded),
              label: const Text('Import Program'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.primaryColor),
                foregroundColor: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  final TrainingProgram program;
  const _ProgramCard({required this.program});

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<ProgramManager>();
    final isActive = manager.activeEnrollment?.programId == program.id &&
        (manager.activeEnrollment?.isActive ?? false);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: isActive
            ? Border.all(color: AppTheme.primaryColor.withOpacity(0.5))
            : null,
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProgramDetailScreen(program: program),
          ),
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (isActive) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'ACTIVE',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (program.isImported)
                              Icon(
                                Icons.download_done_rounded,
                                size: 14,
                                color: AppTheme.textSecondary.withOpacity(0.6),
                              ),
                          ],
                        ),
                        if (isActive || program.isImported)
                          const SizedBox(height: 4),
                        Text(
                          program.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (program.author != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'by ${program.author}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: AppTheme.textSecondary,
                    ),
                    color: AppTheme.surfaceColor,
                    onSelected: (value) =>
                        _handleMenuAction(context, value, manager),
                    itemBuilder: (_) => [
                      if (!isActive)
                        const PopupMenuItem(
                          value: 'start',
                          child: Row(
                            children: [
                              Icon(Icons.play_arrow_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Start Program'),
                            ],
                          ),
                        ),
                      if (isActive)
                        const PopupMenuItem(
                          value: 'leave',
                          child: Row(
                            children: [
                              Icon(Icons.stop_circle_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Leave Program'),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                program.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              // Stats row
              Row(
                children: [
                  _StatChip(
                    icon: Icons.calendar_today_rounded,
                    label: '${program.durationWeeks} weeks',
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    icon: Icons.fitness_center_rounded,
                    label: '${program.trainingDaysPerWeek}×/week',
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    icon: Icons.layers_rounded,
                    label: '${program.phases.length} phases',
                  ),
                ],
              ),
              // Phase pills
              if (program.phases.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: program.phases.map((phase) {
                    final color = _phaseColor(program.phases.indexOf(phase));
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Text(
                        'W${phase.startWeek}–${phase.endWeek}: ${phase.name}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _phaseColor(int index) {
    const colors = [
      Color(0xFFC8491A),
      Color(0xFF1A6BC8),
      Color(0xFF1A8C4E),
    ];
    return colors[index % colors.length];
  }

  Future<void> _handleMenuAction(
    BuildContext context,
    String action,
    ProgramManager manager,
  ) async {
    switch (action) {
      case 'start':
        await manager.enrollInProgram(program.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Started "${program.name}"'),
              backgroundColor: AppTheme.primaryColor,
            ),
          );
        }
      case 'leave':
        await manager.leaveProgram();
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppTheme.surfaceColor,
            title: const Text('Delete Program?'),
            content: Text('Remove "${program.name}" permanently?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          await manager.deleteProgram(program.id);
        }
    }
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ImportFAB extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => _showImportDialog(context),
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.upload_rounded),
      label: const Text('Import'),
    );
  }
}

void _showImportDialog(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surfaceColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ImportBottomSheet(),
  );
}

class _ImportBottomSheet extends StatefulWidget {
  @override
  State<_ImportBottomSheet> createState() => _ImportBottomSheetState();
}

class _ImportBottomSheetState extends State<_ImportBottomSheet> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) {
      _controller.text = data!.text!;
    }
  }

  Future<void> _import() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Paste JSON first');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Validate JSON structure before importing
      final decoded = jsonDecode(text);
      if (decoded is! Map || !decoded.containsKey('name')) {
        throw const FormatException(
          'Invalid format. Must be a training program JSON with a "name" field.',
        );
      }

      final manager = context.read<ProgramManager>();
      final program = await manager.importProgramFromJson(text);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported "${program.name}"'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('FormatException: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Import Training Program',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Paste a training program JSON below. Must include phases, weekly schedule, exercises with set schemes, tempo, and rest times.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: _error != null
                    ? Colors.red.withOpacity(0.5)
                    : AppTheme.textSecondary.withOpacity(0.2),
              ),
            ),
            child: TextField(
              controller: _controller,
              maxLines: 10,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: AppTheme.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: '{ "name": "My 12-Week Plan", ... }',
                hintStyle: TextStyle(
                  color: AppTheme.textSecondary.withOpacity(0.5),
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pasteFromClipboard,
                icon: const Icon(Icons.paste_rounded, size: 16),
                label: const Text('Paste'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: BorderSide(
                    color: AppTheme.textSecondary.withOpacity(0.4),
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _isLoading ? null : _import,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Import'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
