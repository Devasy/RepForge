// Opt in with RUN_LIVE_COACH_EVAL=1; uses environment credentials and read tools.
import 'dart:convert';
import 'dart:io';
import 'package:ai_orchestration/ai_orchestration.dart' as orchestration;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/sqlite_storage_service.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/managers/pr_manager.dart';
import 'package:repforge/services/ai/coach_tool_service.dart';
import 'package:repforge/services/ai/sql_query_service.dart';
import 'package:repforge/services/ai/coach_instructions.dart';
import 'package:repforge/services/ai/gemini_ai_service.dart';
import 'package:repforge/services/ai/orchestration/repforge_tools.dart';
import 'package:repforge/services/ai/observability/agent_tracing.dart';
import 'package:repforge/services/ai/observability/langfuse_config.dart';
import 'package:repforge/services/ai/observability/langfuse_service.dart';

http.Client client() {
  final io = HttpClient();
  final proxy =
      Platform.environment['HTTPS_PROXY'] ??
      Platform.environment['https_proxy'];
  if (proxy != null) {
    final uri = Uri.parse(proxy);
    io.findProxy = (_) => 'PROXY ${uri.host}:${uri.port}';
  }
  final ca = Platform.environment['SSL_CERT_FILE'];
  if (ca != null) SecurityContext.defaultContext.setTrustedCertificates(ca);
  return IOClient(io);
}

void main() {
  final enabled = Platform.environment['RUN_LIVE_COACH_EVAL'] == '1';
  test(
    'complex coaching queries use real tools and actual Vertex model',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final key = Platform.environment['VERTEX_API_KEY'];
      expect(
        key,
        isNotEmpty,
        reason: 'Set the environment-bound Vertex credential.',
      );
      final path =
          '${Directory.systemTemp.path}/coach-live-${DateTime.now().microsecondsSinceEpoch}.db';
      final storage = SqliteStorageService(databasePathOverride: path);
      await storage.init();
      final wp = WorkoutProvider(
        storage,
        programManager: ProgramManager(storage),
      );
      final pr = PRManager(storage);
      final productionRuntime =
          Platform.environment['COACH_EVAL_PRODUCTION_RUNTIME'] == '1';
      final tracingEnabled = Platform.environment['COACH_EVAL_LANGFUSE'] == '1';
      final tracing = tracingEnabled
          ? LangfuseService(write: (_) async {}, clientFactory: client)
          : null;
      final ai = GeminiAiService(modelClientFactory: client)
        ..init(
          key!,
          backend: GeminiBackend.vertexExpress,
          model: 'gemini-3.8-flash',
          thinkingLevel: 'medium',
          maxToolRounds: int.parse(
            Platform.environment['COACH_EVAL_MAX_ROUNDS'] ?? '8',
          ),
        );
      try {
        if (tracing != null) {
          expect(
            productionRuntime,
            isTrue,
            reason: 'Langfuse evaluation requires the core runtime.',
          );
          await tracing.save(
            LangfuseConfig(
              host: Platform.environment['LANGFUSE_BASE_URL']!,
              publicKey: Platform.environment['LANGFUSE_PUBLIC_KEY']!,
              secretKey: Platform.environment['LANGFUSE_SECRET_KEY']!,
              enabled: true,
            ),
          );
          await tracing.testConnection(tracing.config);
        }
        final now = DateTime.now();
        final backupPath = Platform.environment['COACH_EVAL_BACKUP'];
        if (backupPath != null) {
          final backup =
              jsonDecode(await File(backupPath).readAsString())
                  as Map<String, dynamic>;
          // Do not import credentials, identities, chats, drafts or app settings.
          await storage.importData(
            jsonEncode({
              'backupFormatVersion': backup['backupFormatVersion'],
              for (final key in [
                'sessions',
                'routines',
                'targets',
                'muscleGroups',
                'customExercises',
                'exerciseOverrides',
                'trainingPrograms',
                'personalRecords',
              ])
                if (backup.containsKey(key)) key: backup[key],
            }),
          );
        } else {
          await storage.saveRoutine(
            Routine(
              id: 'back-biceps',
              name: 'Back Biceps',
              exerciseIds: ['barbell_row', 'bicep_curl'],
            ),
          );
          for (final days in [175, 150, 90, 30, 7]) {
            await storage.saveWorkoutSession(
              WorkoutSession(
                id: 'synthetic-$days',
                date: now.subtract(Duration(days: days)),
                routineId: 'back-biceps',
                duration: 45,
                exercises: [
                  ExerciseLog(
                    exerciseId: 'incline_bench_press',
                    sets: [WorkoutSet(weight: days > 90 ? 40 : 50, reps: 8)],
                  ),
                  ExerciseLog(
                    exerciseId: 'bench_press',
                    sets: days > 90
                        ? [WorkoutSet(weight: 60, reps: 8)]
                        : [
                            WorkoutSet(weight: 50, reps: 12),
                            WorkoutSet(weight: 40, reps: 15),
                          ],
                  ),
                  ExerciseLog(
                    exerciseId: 'barbell_row',
                    sets: [WorkoutSet(weight: 50, reps: 8)],
                  ),
                  ExerciseLog(
                    exerciseId: 'bicep_curl',
                    sets: [WorkoutSet(weight: 12.5, reps: days > 90 ? 8 : 10)],
                  ),
                ],
              ),
            );
          }
        }
        await wp.init();
        await pr.backfillFromSessions(wp.sessions);
        final tools = CoachToolService(
          workoutProvider: wp,
          prManager: pr,
          sqlQuery: SqlQueryService(path),
        );
        final readTools = [
          Tool(
            functionDeclarations: [
              for (final t in tools.buildTools())
                for (final f
                    in t.functionDeclarations ?? <FunctionDeclaration>[])
                  if (!RepForgeTool.writes.contains(f.name)) f,
            ],
          ),
        ];
        final prompts = backupPath != null
            ? [
                'Analyze my last six months across major muscle groups, including incline chest work. Compare dated early and recent observed sets, identify improvements versus uncertain or unassessed groups, and give practical next actions. Discover my logged exercises; do not ask me to choose them. Do not modify anything.',
                'Has my chest strength improved over six months, or just volume? Compare Incline Bench Press and my logged flat dumbbell chest press. Use SQL to verify actual dated weight/reps pairs and PRs, compare similar rep ranges, account for dropsets and load metadata, and explain uncertainty. Do not modify anything.',
                'For my saved routine named back biceps, compare exercise performance over six months and identify gaps. Discover and match that exact saved routine, distinguish it from other back/biceps routines, compare handles separately when recorded, and give achievable next actions. I mean biceps, not triceps. Do not modify anything.',
                'Analyze my Pull-ups over six months. Use SQL for dated early versus recent sets and the best observed performances. Check assistance, extra load, recorded body weight, load mode and encoding: is a bigger number really stronger? Explain what can and cannot be compared and recommend a sensible next step. Do not modify anything.',
                'Does my sleep prove recovery is good and explain my six-month progress? Check matched sleep coverage using SQL, distinguish records absent from this imported backup from actual missing sleep or a disconnected device, avoid causal claims, and give the smallest useful next action. Do not modify anything.',
              ]
            : [
                'Analyze my last six months across major muscle groups. Include incline chest work, identify improvements versus uncertain groups, and give practical next actions. Do not ask me to choose exercises already logged.',
                'My chest tonnage increased, so am I stronger? Compare my actual early and recent sets over six months; verify the numbers with SQL and explain any conflicting signals.',
                'For my saved Back Biceps routine, compare exercise performance over six months and identify gaps. I mean biceps, not triceps. Do not modify anything.',
                'What is my bench PR over six months? Use SQL to show the actual dated weight/reps pair; do not combine independent maximum weight and reps.',
                'Does my sleep prove recovery is good and explain my six-month progress? Check matched sleep coverage using SQL, distinguish missing data, and avoid causal claims.',
              ];
        final results = <Map<String, Object?>>[];
        final failedCases = <int>[];
        final selectedCase = int.tryParse(
          Platform.environment['COACH_EVAL_CASE'] ?? '',
        );
        if (selectedCase != null) {
          expect(selectedCase, inInclusiveRange(1, prompts.length));
        }
        for (var index = 0; index < prompts.length; index++) {
          if (selectedCase != null && selectedCase != index + 1) continue;
          final calls = <Map<String, Object?>>[];
          final answer = StringBuffer();
          final trace = tracing == null
              ? null
              : AgentTracing(
                  tracing,
                  'coach-eval-${now.microsecondsSinceEpoch}',
                  metadata: {
                    'kind': 'coach_live_eval',
                    'case': index + 1,
                    'dataSource': backupPath == null
                        ? 'synthetic'
                        : 'training_backup',
                    'maxModelCalls': ai.maxToolRounds,
                  },
                );
          Future<void> saveResult({Object? error}) async {
            final result = <String, Object?>{
              'case': index + 1,
              'prompt': prompts[index],
              'provider': ai.backend.name,
              'resolvedModel': ai.currentModel,
              'runtime': productionRuntime ? 'production_limits' : 'legacy',
              'maxModelCalls': ai.maxToolRounds,
              if (trace != null) 'langfuseTraceId': trace.traceId,
              if (trace != null) 'langfuseSessionId': trace.sessionId,
              if (tracing != null) 'langfuseExportStatus': tracing.status,
              'dataSource': backupPath == null
                  ? 'synthetic'
                  : 'training_backup',
              'calls': calls,
              'answer': answer.toString(),
              if (error != null) 'error': error.toString(),
            };
            results.add(result);
            final output = Platform.environment['COACH_EVAL_OUTPUT'];
            if (output != null) {
              await File(output).writeAsString(
                const JsonEncoder.withIndent('  ').convert(results),
              );
            }
          }

          try {
            final systemPrompt =
                '${coachingEvidenceInstructions(webSearchAvailable: false)}\nUse plain text for this evaluation. All load is recorded in kg. Today is ${now.toIso8601String().substring(0, 10)}.';
            Future<Map<String, Object?>> recordCall(FunctionCall call) async {
              final result = await tools.handleCall(call);
              calls.add({
                'name': call.name,
                'args': call.args,
                'result': result,
              });
              return result;
            }

            final reply = productionRuntime
                ? productionReply(
                    ai: ai,
                    service: tools,
                    tools: readTools,
                    prompt: prompts[index],
                    systemPrompt: systemPrompt,
                    callback: recordCall,
                    trace: trace,
                  )
                : ai.streamCoachReply(
                    userMessage: prompts[index],
                    systemPrompt: systemPrompt,
                    history: [],
                    tools: readTools,
                    onToolCall: recordCall,
                  );
            await for (final chunk in reply) {
              answer.write(chunk);
            }
          } catch (error) {
            trace?.finish(failed: true);
            await tracing?.flush();
            await saveResult(error: error);
            failedCases.add(index + 1);
            continue;
          }
          trace?.finish();
          await tracing?.flush();
          if (tracing != null) expect(tracing.status, 'Trace sent');
          // Persist evidence before assertions so failures remain reviewable.
          await saveResult();
          expect(answer.length, greaterThan(100));
          expect(calls, isNotEmpty);
          if ([1, 3, 4].contains(index)) {
            expect(calls.any((c) => c['name'] == 'run_sql_query'), isTrue);
          }
          if (index == 0) {
            expect(
              calls.any(
                (c) =>
                    c['name'] == 'get_progress_overview' ||
                    c['name'] == 'get_exercise_performance',
              ),
              isTrue,
            );
          }
        }
        expect(
          failedCases,
          isEmpty,
          reason: 'See saved per-case failure evidence.',
        );
      } finally {
        await tracing?.flush();
        tracing?.dispose();
        ai.dispose();
        wp.dispose();
        await storage.close();
        await File(path).delete();
      }
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 20)),
  );
}

// Match app runtime limits while retaining the read-only evaluation registry.
Stream<String> productionReply({
  required GeminiAiService ai,
  required CoachToolService service,
  required List<Tool> tools,
  required String prompt,
  required String systemPrompt,
  required Future<Map<String, Object?>> Function(FunctionCall) callback,
  AgentTracing? trace,
}) async* {
  final registry = orchestration.ToolRegistry([
    for (final tool in tools)
      for (final declaration
          in tool.functionDeclarations ?? <FunctionDeclaration>[])
        ObservedReadTool(service, declaration, callback),
  ]);
  final runtime = orchestration.AgentRuntime(
    store: orchestration.MemoryCheckpointStore(),
    model: trace == null ? ai : TracedModel(ai, trace),
    limits: orchestration.RunLimits(
      activeTimeout: Duration(minutes: ai.maxToolRounds * 10 + 1),
      maxModelCalls: ai.maxToolRounds,
      maxToolCalls: ai.maxToolRounds * 16,
      maxSteps: ai.maxToolRounds * 20 + 1,
    ),
  );
  final handle = await runtime.start(
    workflow: orchestration.chatWorkflow(
      id: 'live-evaluation',
      modelId: ai.currentModel,
      systemPrompt: systemPrompt,
      tools: trace?.tools(registry) ?? registry,
      authorize: (_, _) => orchestration.ToolAuthorization.allow,
    ),
    threadId: orchestration.newIdentifier(),
    input: {'text': prompt},
  );
  await for (final event in handle.events) {
    if (event.type == orchestration.RunEventType.textDelta) {
      yield event.data['text']! as String;
    }
  }
  final result = await handle.done;
  if (result.status != orchestration.RunStatus.completed) {
    throw StateError(result.failure?['message']?.toString() ?? 'Run failed');
  }
}

class ObservedReadTool extends RepForgeTool {
  ObservedReadTool(super.service, super.declaration, this.callback) {
    if (definition.effect != orchestration.ToolEffect.read) {
      throw ArgumentError('Live evaluation only permits read tools');
    }
  }
  final Future<Map<String, Object?>> Function(FunctionCall) callback;
  @override
  Future<orchestration.ToolOutcome> execute(
    orchestration.ToolContext context,
  ) async {
    context.cancellation.check();
    return orchestration.ToolSuccess(
      await callback(FunctionCall(context.call.name, context.call.arguments)),
    );
  }
}
