// Main App Entry Point
//
// Following Dependency Inversion Principle: we create concrete implementations
// here at the composition root and inject them into high-level modules.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'services/debug_log_buffer.dart';
import 'services/storage_service.dart';
import 'services/ml_service.dart';
import 'services/ai/gemini_ai_service.dart';
import 'services/ai/agent_orchestrator.dart';
import 'services/ai/coach_tool_service.dart';
import 'services/health_connect_service.dart';
import 'services/interfaces/storage_service_interface.dart';
import 'services/interfaces/ml_service_interface.dart';
import 'services/interfaces/health_connect_service_interface.dart';
import 'services/workout_provider.dart';
import 'services/settings_provider.dart';
import 'services/api_service.dart';
import 'services/managers/program_manager.dart';
import 'services/managers/history_manager.dart';
import 'services/managers/health_sync_manager.dart';
import 'services/managers/pr_manager.dart';
import 'services/managers/readiness_manager.dart';
import 'services/managers/health_history_manager.dart';
import 'services/managers/conversation_manager.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  DebugLogBuffer.attach();
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Enable edge-to-edge: draw behind status bar AND nav bar
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Keep all system overlays transparent; content uses SafeArea for insets
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  runApp(const WorkoutLoggerApp());
}

class WorkoutLoggerApp extends StatelessWidget {
  // Singleton instances created once at app startup
  // This ensures the same instances are used throughout the app lifecycle
  static final IStorageService _storageService = StorageService();
  static final IMLService _mlService = MLService();
  static final IHealthConnectService _healthConnectService = HealthConnectService();
  static final ProgramManager _programManager = ProgramManager(_storageService);
  static final SettingsProvider _settingsProvider = SettingsProvider(_storageService);
  // HealthSyncManager uses the in-memory settings flag — no storage I/O on sync.
  static final HealthSyncManager _healthSyncManager =
      HealthSyncManager(_healthConnectService, _settingsProvider);
  // HistoryManager is the single owner of session history + HC sync trigger.
  static final HistoryManager _historyManager =
      HistoryManager(_storageService, healthSyncManager: _healthSyncManager);
  static final PRManager _prManager = PRManager(_storageService);
  // ReadinessManager reads HC sleep/heart data; gated by the in-memory
  // readiness setting so refresh() is a no-op until the user opts in.
  static final ReadinessManager _readinessManager =
      ReadinessManager(_healthConnectService, _storageService, _settingsProvider);
  // Serves arbitrary-range sleep/HR data to the detail screens.
  static final HealthHistoryManager _healthHistoryManager =
      HealthHistoryManager(_healthConnectService, _storageService);
  static final GeminiAiService _geminiService =
      GeminiAiService(storage: _storageService);
  static final ConversationManager _conversationManager =
      ConversationManager(_storageService);

  const WorkoutLoggerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Composition Root: Provide the singleton implementations
    // This is the only place where we reference concrete implementations.
    // All other code depends on abstractions (interfaces).
    return MultiProvider(
      providers: [
        // Provide the storage service interface for direct access if needed
        Provider<IStorageService>.value(value: _storageService),
        // Provide the ML service interface for direct access if needed
        Provider<IMLService>.value(value: _mlService),
        // IHealthConnectService stays in tree for ProfileScreen permission flow
        Provider<IHealthConnectService>.value(value: _healthConnectService),
        // Provide the ApiService singleton via DI
        Provider<ApiService>.value(value: ApiService()),
        // ProgramManager passed to tree directly
        ChangeNotifierProvider<ProgramManager>.value(value: _programManager),
        // SettingsProvider for user preferences (weight unit, increments)
        ChangeNotifierProvider<SettingsProvider>.value(value: _settingsProvider),
        // HistoryManager is the single source of truth for session history.
        // Provided as ChangeNotifier so HistoryScreen rebuilds on sync badge changes.
        ChangeNotifierProvider<HistoryManager>.value(value: _historyManager),
        ChangeNotifierProvider<PRManager>.value(value: _prManager),
        ChangeNotifierProvider<ReadinessManager>.value(value: _readinessManager),
        Provider<HealthHistoryManager>.value(value: _healthHistoryManager),
        // GeminiAiService is the single AI backend instance. It's a ChangeNotifier
        // (settings UI watches isConfigured/model), so it's provided as such.
        // Consumers that should depend on the abstraction (the coach ViewModel,
        // program generator) receive it typed as IAiService at construction —
        // the future firebase_ai swap point — without a separate provider.
        ChangeNotifierProvider<GeminiAiService>.value(value: _geminiService),
        ChangeNotifierProvider<ConversationManager>.value(
          value: _conversationManager,
        ),
        // WorkoutProvider receives dependencies via constructor injection
        ChangeNotifierProvider(
          create: (_) => WorkoutProvider(
            _storageService,
            mlService: _mlService,
            historyManager: _historyManager,
            programManager: _programManager,
          ),
        ),
        // CoachToolService backs AI tool calls; reads from WorkoutProvider + PRManager.
        Provider<CoachToolService>(
          create: (ctx) => CoachToolService(
            ctx.read<WorkoutProvider>(),
            ctx.read<PRManager>(),
          ),
        ),
        Provider<AgentOrchestrator>(
          create: (ctx) => AgentOrchestrator(
            ai: ctx.read<GeminiAiService>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Workout Logger',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const AppInitializer(),
      ),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _initialized = false;
  bool _needsNamePrompt = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Capture all providers synchronously before any awaits.
    final provider = context.read<WorkoutProvider>();
    final settings = context.read<SettingsProvider>();
    final historyManager = context.read<HistoryManager>();
    final prManager = context.read<PRManager>();
    final api = context.read<ApiService>();
    final gemini = context.read<GeminiAiService>();
    final readiness = context.read<ReadinessManager>();

    try {
      await provider.init();
      await settings.init();
      gemini.init(settings.geminiApiKey, model: settings.geminiModel);
      try {
        await gemini.loadUsage();
      } catch (e, st) {
        debugPrint('gemini.loadUsage failed: $e\n$st');
      }
      await historyManager.loadSessions();
      await prManager.load();
      await prManager.backfillFromSessions(historyManager.sessions);

      final version = await settings.getCurrentVersion();
      final needsName = settings.userName == null || settings.userName!.isEmpty;
      final versionChanged = !needsName &&
          settings.lastSeenVersion != null &&
          settings.lastSeenVersion != version;

      // Fire-and-forget readiness refresh — must run after settings.init()
      // so the opt-in flag is loaded; never blocks or fails app init.
      readiness.refresh();

      // Fire-and-forget analytics in background.
      api.sendHeartbeat();
      api.trackEvent('app_open');
      provider.getQuickStats().then((stats) => api.reportUsage(stats)).catchError(
        (Object e) => debugPrint('Failed to report usage: $e'),
      );

      if (!mounted) return;
      setState(() {
        _initialized = true;
        _needsNamePrompt = needsName;
      });

      if (!needsName && versionChanged) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          await showVersionUpdateSheet(context, version);
          if (mounted) await settings.markVersionSeen(version);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppTheme.error),
              const SizedBox(height: 16),
              Text(
                'Failed to initialize app',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _error = null;
                    _initialized = false;
                  });
                  _initializeApp();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_initialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.fitness_center,
                size: 64,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 24),
              Text(
                'Workout Logger',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(color: AppTheme.primaryColor),
            ],
          ),
        ),
      );
    }

    if (_needsNamePrompt) {
      return WelcomePage(
        onComplete: () => setState(() => _needsNamePrompt = false),
      );
    }

    return const HomeScreen();
  }
}
