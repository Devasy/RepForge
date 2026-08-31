// Wraps every test in this suite. See dart.dev/go/flutter-test-config.

import 'dart:async';

import 'package:repforge/screens/widgets/rf_widgets.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // AmbientGlow drifts on a loop that never completes, which would keep
  // pumpAndSettle waiting for a frame that never stops coming.
  AmbientGlow.motionEnabled = false;
  await testMain();
}
