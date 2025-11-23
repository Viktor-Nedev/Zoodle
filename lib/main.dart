import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth/login_screen.dart';
import 'main_scaffold.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Инициализирай Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Инициализирай Mapbox
  MapboxOptions.setAccessToken(
      "pk.eyJ1IjoidmlrZGV2IiwiYSI6ImNtZ3V5d2JkdzAwZ2Myb3NneXZoYm84M2cifQ.5OV7UwssKzH5Emz7T8aZ5w");

  runApp(const AnimalRescueApp());
}

class AnimalRescueApp extends StatelessWidget {
  const AnimalRescueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Спаси Животно',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
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
