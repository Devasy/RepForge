// Import Program Screen
//
// Full-screen editor for pasting or typing a TrainingProgram JSON.
// Replaces the cramped bottom-sheet approach so large programs
// (e.g. a 12-week plan at ~100 KB) can be pasted comfortably.
//
// Features:
//   • Expandable text area that fills the screen
//   • Live character / line counter
//   • "Validate JSON" step before committing to storage
//   • Actionable error messages (missing field, bad type, etc.)
//   • Clear button to wipe the field

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/workout_provider.dart';
import '../../theme/app_theme.dart';

class ImportProgramScreen extends StatefulWidget {
  const ImportProgramScreen({super.key});

  @override
  State<ImportProgramScreen> createState() => _ImportProgramScreenState();
}

class _ImportProgramScreenState extends State<ImportProgramScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  _ValidationState _validationState = _ValidationState.idle;
  String? _validationError;
  Map<String, dynamic>? _parsed; // non-null = validated ok

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Import Program'),
        actions: [
          if (_ctrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Clear',
              onPressed: _clearField,
            ),
        ],
      ),
      body: Column(
        children: [
          _buildInstructions(),
          Expanded(child: _buildTextField()),
          _buildStatusBar(),
          _buildActionBar(),
        ],
      ),
    );
  }

  // ── Instructions ─────────────────────────────────────────────────────

  Widget _buildInstructions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: AppTheme.surfaceColor,
      child: Text(
        'Paste a TrainingProgram JSON. '
        'Required fields: name · totalWeeks · phases · weeks.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  // ── Text field ────────────────────────────────────────────────────────

  Widget _buildTextField() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: TextField(
        controller: _ctrl,
        scrollController: _scrollCtrl,
        maxLines: null,  // expands to fill available height
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: AppTheme.textPrimary,
          height: 1.5,
        ),
        decoration: InputDecoration(
          hintText: '{\n  "name": "My Program",\n  "totalWeeks": 12,\n  ...\n}',
          hintStyle: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: AppTheme.textMuted,
          ),
          filled: true,
          fillColor: AppTheme.surfaceColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(
              color: _borderColor,
              width: _validationState != _ValidationState.idle ? 1.5 : 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: _borderColor, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: _borderColor, width: 2),
          ),
          contentPadding: const EdgeInsets.all(AppSpacing.md),
        ),
        onChanged: (_) {
          // Reset validation when user edits
          if (_validationState != _ValidationState.idle) {
            setState(() {
              _validationState = _ValidationState.idle;
              _validationError = null;
              _parsed = null;
            });
          } else {
            setState(() {}); // refresh char counter
          }
        },
      ),
    );
  }

  Color get _borderColor {
    switch (_validationState) {
      case _ValidationState.valid:
        return AppTheme.success;
      case _ValidationState.invalid:
        return AppTheme.error;
      case _ValidationState.idle:
        return AppTheme.surfaceColor;
    }
  }

  // ── Status bar (char / line count + validation message) ──────────────

  Widget _buildStatusBar() {
    final text = _ctrl.text;
    final chars = text.length;
    final lines = text.isEmpty ? 0 : '\n'.allMatches(text).length + 1;
    final kb = (text.length / 1024).toStringAsFixed(1);

    return Container(
      color: AppTheme.surfaceColor,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Text(
            '$chars chars · $lines lines · $kb KB',
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textMuted,
              fontFamily: 'monospace',
            ),
          ),
          const Spacer(),
          if (_validationState == _ValidationState.valid)
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 14, color: AppTheme.success),
                SizedBox(width: 4),
                Text(
                  'Valid JSON',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          if (_validationState == _ValidationState.invalid &&
              _validationError != null)
            Expanded(
              child: Text(
                _validationError!,
                style: const TextStyle(fontSize: 11, color: AppTheme.error),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  // ── Action bar ────────────────────────────────────────────────────────

  Widget _buildActionBar() {
    final canValidate = _ctrl.text.trim().isNotEmpty &&
        _validationState != _ValidationState.valid;
    final canImport = _validationState == _ValidationState.valid && _parsed != null;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: const BoxDecoration(
          color: AppTheme.cardColor,
          border: Border(top: BorderSide(color: AppTheme.surfaceColor, width: 1)),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: canValidate ? _validate : null,
                child: const Text('Validate'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: ElevatedButton(
                onPressed: canImport ? _import : null,
                style: canImport
                    ? null
                    : ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.surfaceColor,
                      ),
                child: const Text('Import'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Logic ─────────────────────────────────────────────────────────────

  void _clearField() {
    _ctrl.clear();
    setState(() {
      _validationState = _ValidationState.idle;
      _validationError = null;
      _parsed = null;
    });
  }

  void _validate() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Top-level value must be a JSON object {}');
      }

      // Required field checks
      _requireField(decoded, 'name', String);
      _requireField(decoded, 'totalWeeks', int);
      _requireField(decoded, 'phases', List);
      _requireField(decoded, 'weeks', List);

      // Light structural check on first week
      if ((decoded['weeks'] as List).isNotEmpty) {
        final w = (decoded['weeks'] as List).first as Map<String, dynamic>;
        _requireField(w, 'weekNumber', int);
        _requireField(w, 'days', List);
      }

      setState(() {
        _validationState = _ValidationState.valid;
        _validationError = null;
        _parsed = decoded;
      });
    } on FormatException catch (e) {
      setState(() {
        _validationState = _ValidationState.invalid;
        _validationError = e.message;
        _parsed = null;
      });
    } catch (e) {
      setState(() {
        _validationState = _ValidationState.invalid;
        _validationError = e.toString().replaceFirst('Exception: ', '');
        _parsed = null;
      });
    }
  }

  void _requireField(Map<String, dynamic> map, String key, Type type) {
    if (!map.containsKey(key)) {
      throw FormatException('Missing required field: "$key"');
    }
    if (type == int && map[key] is! int) {
      throw FormatException('"$key" must be an integer, got ${map[key].runtimeType}');
    }
    if (type == String && map[key] is! String) {
      throw FormatException('"$key" must be a string, got ${map[key].runtimeType}');
    }
    if (type == List && map[key] is! List) {
      throw FormatException('"$key" must be an array, got ${map[key].runtimeType}');
    }
  }

  Future<void> _import() async {
    if (_parsed == null) return;

    try {
      final provider = context.read<WorkoutProvider>();
      // Re-encode the validated parsed map to pass through importFromJson
      final json = jsonEncode(_parsed);
      await provider.programManager.importFromJson(json);

      if (mounted) {
        Navigator.pop(context, true); // signal success to caller
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import failed: ${_shortError(e)}'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  String _shortError(Object e) {
    final s = e.toString().replaceFirst('Exception: ', '');
    return s.length > 120 ? '${s.substring(0, 120)}…' : s;
  }
}

enum _ValidationState { idle, valid, invalid }
