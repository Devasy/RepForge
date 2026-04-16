// Main App Entry Point
//
// Following Dependency Inversion Principle: we create concrete implementations
// here at the composition root and inject them into high-level modules.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'services/storage_service.dart';
import 'services/ml_service.dart';
import 'services/interfaces/storage_service_interface.dart';
import 'services/interfaces/ml_service_interface.dart';
import 'services/workout_provider.dart';
import 'services/settings_provider.dart';
import 'services/api_service.dart';
import 'services/managers/program_manager.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.backgroundColor,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const WorkoutLoggerApp());
}

class WorkoutLoggerApp extends StatelessWidget {
  // Singleton instances created once at app startup
  // This ensures the same instances are used throughout the app lifecycle
  static final IStorageService _storageService = StorageService();
  static final IMLService _mlService = MLService();
  static final ProgramManager _programManager = ProgramManager(_storageService);
  static final SettingsProvider _settingsProvider = SettingsProvider(_storageService);

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
        // Provide the ApiService singleton via DI
        Provider<ApiService>.value(value: ApiService()),
        // ProgramManager passed to tree directly
        ChangeNotifierProvider<ProgramManager>.value(value: _programManager),
        // SettingsProvider for user preferences (weight unit, increments)
        ChangeNotifierProvider<SettingsProvider>.value(value: _settingsProvider),
        // WorkoutProvider receives dependencies via constructor injection
        ChangeNotifierProvider(
          create: (_) => WorkoutProvider(
            _storageService,
            mlService: _mlService,
            programManager: _programManager,
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
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      final provider = context.read<WorkoutProvider>();
      await provider.init();

      final settings = context.read<SettingsProvider>();
      await settings.init();

      // Fire-and-forget analytics in background
      final api = context.read<ApiService>();
      api.sendHeartbeat();
      api.trackEvent('app_open');
      provider
          .getQuickStats()
          .then((stats) {
            api.reportUsage(stats);
          })
          .catchError((e) {
            debugPrint('Failed to report usage: $e');
          });

      setState(() => _initialized = true);
    } catch (e) {
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

    return const HomeScreen();
  }
}
