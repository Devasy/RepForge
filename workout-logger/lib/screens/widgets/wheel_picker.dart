import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

/// Two-column wheel picker for weight + reps input.
class WheelPickerField extends StatelessWidget {
  const WheelPickerField({
    super.key,
    required this.weight,
    required this.reps,
    required this.onWeightChanged,
    required this.onRepsChanged,
    this.weightStep = 2.5,
    this.weightMin = 0,
    this.weightMax = 200,
    this.repsMin = 1,
    this.repsMax = 50,
  });

  final double weight;
  final int reps;
  final ValueChanged<double> onWeightChanged;
  final ValueChanged<int> onRepsChanged;
  final double weightStep;
  final double weightMin;
  final double weightMax;
  final int repsMin;
  final int repsMax;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 14,
          child: _SingleWheel<double>(
            label: 'WEIGHT',
            unit: 'kg',
            color: AppColors.primary,
            value: weight,
            values: _buildDoubleRange(weightMin, weightMax, weightStep),
            formatter: (v) => v == v.truncateToDouble()
                ? v.toInt().toString()
                : v.toStringAsFixed(1),
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onWeightChanged(v);
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 10,
          child: _SingleWheel<int>(
            label: 'REPS',
            unit: '',
            color: AppColors.secondary,
            value: reps,
            values: List.generate(repsMax - repsMin + 1, (i) => repsMin + i),
            formatter: (v) => v.toString(),
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onRepsChanged(v);
            },
          ),
        ),
      ],
    );
  }

  static List<double> _buildDoubleRange(
      double min, double max, double step) {
    final result = <double>[];
    double v = min;
    while (v <= max + 0.001) {
      result.add(double.parse(v.toStringAsFixed(2)));
      v += step;
    }
    return result;
  }
}

class _SingleWheel<T> extends StatefulWidget {
  const _SingleWheel({
    required this.label,
    required this.unit,
    required this.color,
    required this.value,
    required this.values,
    required this.formatter,
    required this.onChanged,
  });

  final String label;
  final String unit;
  final Color color;
  final T value;
  final List<T> values;
  final String Function(T) formatter;
  final ValueChanged<T> onChanged;

  @override
  State<_SingleWheel<T>> createState() => _SingleWheelState<T>();
}

class _SingleWheelState<T> extends State<_SingleWheel<T>> {
  late FixedExtentScrollController _ctrl;
  int _selectedIndex = 0;

  static const double _itemH = 38;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.values.indexOf(widget.value);
    if (_selectedIndex < 0) _selectedIndex = 0;
    _ctrl = FixedExtentScrollController(initialItem: _selectedIndex);
  }

  @override
  void didUpdateWidget(_SingleWheel<T> old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      final idx = widget.values.indexOf(widget.value);
      if (idx >= 0 && idx != _selectedIndex) {
        _selectedIndex = idx;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_ctrl.hasClients) _ctrl.jumpToItem(idx);
        });
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x09FFFFFF), Color(0x04FFFFFF)],
        ),
        border: Border.all(color: AppColors.glassBorder),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.label,
                style: TextStyle(fontFamily: 'Geist', 
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              if (widget.unit.isNotEmpty)
                Text(
                  widget.unit,
                  style: TextStyle(fontFamily: 'Geist', 
                    fontSize: 10,
                    color: AppColors.textFaint,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: _itemH * 3,
            child: Stack(
              children: [
                // Selection band
                Positioned(
                  top: _itemH,
                  left: -12,
                  right: -12,
                  child: Container(
                    height: _itemH,
                    decoration: BoxDecoration(
                      color: const Color(0x06FFFFFF),
                      border: Border(
                        top: BorderSide(
                            color: AppColors.glassBorderStrong, width: 1),
                        bottom: BorderSide(
                            color: AppColors.glassBorderStrong, width: 1),
                      ),
                    ),
                  ),
                ),
                // Wheel
                ListWheelScrollView.useDelegate(
                  controller: _ctrl,
                  itemExtent: _itemH,
                  physics: const FixedExtentScrollPhysics(),
                  diameterRatio: 3,
                  overAndUnderCenterOpacity: 0.3,
                  onSelectedItemChanged: (i) {
                    setState(() => _selectedIndex = i);
                    widget.onChanged(widget.values[i]);
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: widget.values.length,
                    builder: (context, i) {
                      final isCurrent = i == _selectedIndex;
                      return Center(
                        child: Text(
                          widget.formatter(widget.values[i]),
                          style: TextStyle(fontFamily: 'GeistMono', 
                            fontSize: isCurrent ? 28 : 16,
                            fontWeight: FontWeight.w600,
                            color: isCurrent
                                ? widget.color
                                : AppColors.textPrimary,
                            letterSpacing:
                                -0.02 * (isCurrent ? 28 : 16),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Top fade
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: _itemH,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.surface,
                            AppColors.surface.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Bottom fade
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: _itemH,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            AppColors.surface,
                            AppColors.surface.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
