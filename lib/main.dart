import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth/login_screen.dart';
import 'main_scaffold.dart';
import 'services/notification_service.dart';

import 'config/app_config.dart';
import 'theme/app_theme.dart';

abstract class AnimalRescueAppController {
  ThemeMode get themeMode;
  void setThemeMode(ThemeMode mode);
  void toggleTheme();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
    final envToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
    if (envToken.isNotEmpty) {
      AppConfig.mapboxAccessToken = envToken;
    }
  } catch (_) {
    // Ignore missing .env; fallback to dart-define.
  }

  runApp(const _StartupGate());
}

class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  late Future<void> _startupFuture;

  @override
  void initState() {
    super.initState();
    _startupFuture = _initializeApp();
  }

  Future<void> _initializeApp() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw TimeoutException(
        'Firebase initialization timed out after 15 seconds.',
      ),
    );

    if (AppConfig.hasMapboxToken) {
      MapboxOptions.setAccessToken(AppConfig.mapboxAccessToken);
      return;
    }

    debugPrint(
      'MAPBOX_ACCESS_TOKEN is missing. Add it to .env or use --dart-define-from-file=.env.',
    );
  }

  void _retryStartup() {
    setState(() {
      _startupFuture = _initializeApp();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _startupFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 40),
                      const SizedBox(height: 16),
                      Text(
                        'Приложението не можа да се стартира.',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _retryStartup,
                        child: const Text('Опитай отново'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return const AnimalRescueApp();
      },
    );
  }
}

class AnimalRescueApp extends StatefulWidget {
  const AnimalRescueApp({super.key});

  static AnimalRescueAppController of(BuildContext context) =>
      context.findAncestorStateOfType<_AnimalRescueAppState>()!;

  @override
  State<AnimalRescueApp> createState() => _AnimalRescueAppState();
}

class _AnimalRescueAppState extends State<AnimalRescueApp>
    implements AnimalRescueAppController {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  ThemeMode get themeMode => _themeMode;

  @override
  void setThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  void toggleTheme() {
    setThemeMode(
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);
  }

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    try {
      final notificationService = NotificationService();
      await notificationService.initialize();
      debugPrint('NotificationService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Спаси Животно',
      theme: AppTheme.greenTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Splash screen докато проверяваме автентификацията
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (snapshot.hasData && snapshot.data != null) {
            // Потребителят е логнат -> покажи основния екран
            debugPrint('Потребителят е логнат: ${snapshot.data!.uid}');
            return const MainScaffold();
          }

          // Потребителят не е логнат -> покажи екрана за вход
          return const LoginScreen();
        },
      ),
    );
  }
}
