import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'config.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/data_repository.dart';
import 'services/firebase_auth_service.dart';
import 'services/firebase_data_repository.dart';
import 'services/mock_auth_service.dart';

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

  final AuthService auth;
  if (kMockAuth) {
    // Mock admin login: admin / ecosense123
    final mockAuth = MockAuthService();
    await mockAuth.init();
    auth = mockAuth;
  } else {
    // Real Firebase Authentication
    auth = FirebaseAuthService();
  }

  // Real Firebase Realtime Database for all sensors, status, logs, appliances, and config.
  final DataRepository repo = FirebaseDataRepository();

  runApp(MyApp(auth: auth, repo: repo));
}
