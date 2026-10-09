import 'package:flutter/material.dart';
import '../../data/body_figure.dart';

class GenderPicker extends StatelessWidget {
  const GenderPicker({super.key, required this.value, required this.onChanged});
  final UserGender value;
  final ValueChanged<UserGender>? onChanged;

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(
      labelText: 'Gender (optional)',
      enabled: onChanged != null,
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<UserGender>(
        value: value,
        isExpanded: true,
        items: const [
          DropdownMenuItem(value: UserGender.male, child: Text('Male')),
          DropdownMenuItem(value: UserGender.female, child: Text('Female')),
          DropdownMenuItem(
            value: UserGender.preferNotToSay,
            child: Text('Prefer not to say'),
          ),
        ],
        onChanged: onChanged == null
            ? null
            : (value) {
                if (value != null) onChanged!(value);
              },
      ),
    ),
  );
}
