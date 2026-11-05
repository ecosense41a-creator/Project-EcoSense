import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/data_repository.dart';
import 'services/firebase_auth_service.dart';
import 'services/firebase_data_repository.dart';
import 'theme/theme_controller.dart';

/// Initializes services and starts the EcoSense application.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with a timeout so it never hangs indefinitely on the
  // splash screen if google-services.json is missing or network is unavailable.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 4));
  } catch (e) {
    debugPrint('Firebase init warning: $e');
  }

  // Connect sign-in and room data to Firebase.
  final AuthService auth = FirebaseAuthService();
  final DataRepository repo = FirebaseDataRepository();

  // Light / Dark / System, cached on the phone so the first frame is right.
  final themeController = ThemeController();
  await themeController.load();

  runApp(MyApp(auth: auth, repo: repo, themeController: themeController));
}
