import 'dart:async';

import 'package:flutter/material.dart';
import '../../data/body_figure.dart';
import 'rf_form_fields.dart';

class GenderPicker extends StatelessWidget {
  const GenderPicker({super.key, required this.value, required this.onChanged});
  final UserGender value;
  final FutureOr<void> Function(UserGender)? onChanged;

  @override
  Widget build(BuildContext context) => RFDropdown<UserGender>(
    label: 'Gender (optional)',
    value: value,
    items: UserGender.values,
    labelBuilder: (gender) => switch (gender) {
      UserGender.male => 'Male',
      UserGender.female => 'Female',
      UserGender.preferNotToSay => 'Prefer not to say',
    },
    onChanged: onChanged == null
        ? null
        : (value) async {
            if (value != null) await onChanged!(value);
          },
  );
}
