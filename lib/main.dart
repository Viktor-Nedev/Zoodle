import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth/login_screen.dart';
import 'main_scaffold.dart';
import 'services/notification_service.dart';

import 'theme/app_theme.dart';

const String _mapboxAccessToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Инициализирай Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Инициализирай Mapbox
  if (_mapboxAccessToken.isEmpty) {
    throw Exception(
      'Missing MAPBOX_ACCESS_TOKEN. Run with --dart-define-from-file=.env',
    );
  }
  MapboxOptions.setAccessToken(_mapboxAccessToken);

  runApp(const AnimalRescueApp());
}

class AnimalRescueApp extends StatefulWidget {
  const AnimalRescueApp({super.key});

  @override
  static _AnimalRescueAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_AnimalRescueAppState>()!;

  State<AnimalRescueApp> createState() => _AnimalRescueAppState();
}

class _AnimalRescueAppState extends State<AnimalRescueApp> {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  void toggleTheme() {
    setThemeMode(_themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);
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
      print("NotificationService initialized successfully");
    } catch (e) {
      print("Error initializing NotificationService: $e");
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
            print("Потребителят е логнат: ${snapshot.data!.uid}");
            return const MainScaffold();
          }

          // Потребителят не е логнат -> покажи екрана за вход
          return const LoginScreen();
        },
      ),
    );
  }
}
