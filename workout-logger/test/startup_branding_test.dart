import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/main.dart';
import 'test_utils/mock_storage_service.dart';
import 'test_utils/test_harness.dart';

class _WaitingStorage extends MockStorageService {
  final ready = Completer<void>();
  @override
  Future<void> init() => ready.future;
}

void main() {
  testWidgets('loading and failed startup keep RepForge branding and retry', (
    tester,
  ) async {
    final storage = _WaitingStorage();
    await tester.pumpWidget(
      TestHarness.wrap(const AppInitializer(), storage: storage),
    );
    await tester.pump();
    expect(find.text('RepForge'), findsOneWidget);
    expect(find.text('Workout Logger'), findsNothing);
    storage.ready.completeError(StateError('Storage unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('Could not start RepForge'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Could not start RepForge'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
