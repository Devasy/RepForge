// Explicitly opt in: RUN_LIVE_COACH_EVAL=1 flutter test test/coach_live_eval_test.dart
// Uses only synthetic records, environment-bound credentials and read tools.
// COACH_EVAL_CASE=1..5 reruns one scenario; COACH_EVAL_OUTPUT saves evidence.
import 'dart:convert';
import 'dart:io';
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
    'complex anonymous coaching queries use real tools and actual Vertex model',
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
      final ai = GeminiAiService(modelClientFactory: client)
        ..init(
          key!,
          backend: GeminiBackend.vertexExpress,
          model: 'gemini-3.8-flash',
          thinkingLevel: 'medium',
          maxToolRounds: 8,
        );
      try {
        final now = DateTime.now();
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
        await wp.init();
        await pr.backfillFromSessions(wp.sessions);
        final tools = CoachToolService(
          workoutProvider: wp,
          prManager: pr,
          sqlQuery: SqlQueryService(path),
        );
        final writes = {
          'create_routine',
          'update_routine',
          'add_custom_exercise',
          'update_exercise',
        };
        final readTools = [
          Tool(
            functionDeclarations: [
              for (final t in tools.buildTools())
                for (final f
                    in t.functionDeclarations ?? <FunctionDeclaration>[])
                  if (!writes.contains(f.name)) f,
            ],
          ),
        ];
        final prompts = [
          'Analyze my last six months across major muscle groups. Include incline chest work, identify improvements versus uncertain groups, and give practical next actions. Do not ask me to choose exercises already logged.',
          'My chest tonnage increased, so am I stronger? Compare my actual early and recent sets over six months; verify the numbers with SQL and explain any conflicting signals.',
          'For my saved Back Biceps routine, compare exercise performance over six months and identify gaps. I mean biceps, not triceps. Do not modify anything.',
          'What is my bench PR over six months? Use SQL to show the actual dated weight/reps pair; do not combine independent maximum weight and reps.',
          'Does my sleep prove recovery is good and explain my six-month progress? Check matched sleep coverage using SQL, distinguish missing data, and avoid causal claims.',
        ];
        final results = <Map<String, Object?>>[];
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
          Future<void> saveResult({Object? error}) async {
            final result = <String, Object?>{
              'case': index + 1,
              'prompt': prompts[index],
              'provider': ai.backend.name,
              'resolvedModel': ai.currentModel,
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
            await for (final chunk in ai.streamCoachReply(
              userMessage: prompts[index],
              systemPrompt:
                  '${coachingEvidenceInstructions(webSearchAvailable: false)}\nUse plain text for this evaluation. All load is recorded in kg. Today is ${now.toIso8601String().substring(0, 10)}.',
              history: [],
              tools: readTools,
              onToolCall: (call) async {
                final result = await tools.handleCall(call);
                calls.add({
                  'name': call.name,
                  'args': call.args,
                  'result': result,
                });
                return result;
              },
            )) {
              answer.write(chunk);
            }
          } catch (error) {
            await saveResult(error: error);
            rethrow;
          }
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
      } finally {
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
