import 'package:flutter/services.dart';

Future<void> loadAnimationFonts() async {
  for (final entry in {
    'Geist': 'assets/fonts/Geist-Variable.ttf',
    'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
  }.entries) {
    await (FontLoader(entry.key)..addFont(rootBundle.load(entry.value))).load();
  }
}
