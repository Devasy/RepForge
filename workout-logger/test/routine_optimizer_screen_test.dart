// Widget tests for RoutineOptimizerScreen.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/routine_optimizer_screen.dart';
import 'package:repforge/services/ai/provider/model_step.dart';
import 'package:repforge/services/ai/runtime/agent_runtime.dart';
import 'package:repforge/services/ai/tools/tool_registry.dart';
import 'package:repforge/services/managers/conversation_manager.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/theme/app_theme.dart';
import 'package:repforge/viewmodels/routine_optimizer_view_model.dart';
import 'test_utils/fake_model_runtime.dart';
import 'test_utils/mock_storage_service.dart';

// ── Test helpers ───────────────────────────────────────────────────────────

final _pushDay = Routine(
  id: 'r1',
  name: 'Push Day',
  exerciseIds: const [],
  createdAt: DateTime.now(),
);

RoutineOptimizerViewModel _buildVm(FakeModelRuntime ai) {
  final storage = MockStorageService();
  final conversations = ConversationManager(storage, kind: 'optimizer');
  final settings = SettingsProvider(storage);
  
  final runtime = DefaultAgentRuntime(
    model: ai,
    tools: const ToolRegistry.empty(),
  );

  return RoutineOptimizerViewModel(
    runtime: runtime,
    conversations: conversations,
    settings: settings,
  );
}

Widget _wrap(RoutineOptimizerViewModel vm) => MaterialApp(
      theme: AppTheme.darkTheme,
      home: ChangeNotifierProvider<RoutineOptimizerViewModel>.value(
        value: vm,
        child: RoutineOptimizerScreen.testBody(_pushDay),
      ),
    );

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  group('RoutineOptimizerScreen', () {
    testWidgets('shows title and routine name in header', (tester) async {
      final vm = _buildVm(FakeModelRuntime());
      await tester.pumpWidget(_wrap(vm));
      await tester.pump();

      expect(find.text('Optimize Routine'), findsOneWidget);
      expect(find.text('Push Day'), findsOneWidget);
    });

    testWidgets('renders seed user message and AI reply', (tester) async {
      final ai = FakeModelRuntime(steps: [
        const ModelTextDelta('Great plan!'),
        const ModelFinish('stop'),
      ]);
      final vm = _buildVm(ai);
      await tester.pumpWidget(_wrap(vm));

      await vm.startForRoutine(_pushDay);
      await tester.pump();

      expect(find.textContaining('Push Day'), findsWidgets);
      expect(find.textContaining('Great plan!'), findsOneWidget);
    });
  });
}
