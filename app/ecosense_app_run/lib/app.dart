import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/data_repository.dart';
import 'theme/eco_theme.dart';
import 'theme/theme_controller.dart';
import 'widgets/eco_background.dart';

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.auth,
    required this.repo,
    required this.themeController,
  });

  final AuthService auth;
  final DataRepository repo;
  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    // Rebuilds the whole app when Settings > Appearance changes.
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) => MaterialApp(
        title: 'EcoSense',
        debugShowCheckedModeBanner: false,
        theme: buildEcoTheme(Brightness.light),
        darkTheme: buildEcoTheme(Brightness.dark),
        themeMode: themeController.mode,
        home: AuthGate(auth: auth, repo: repo, themeController: themeController),
      ),
    );
  }
}

/// Decides which screen to show, based on whether someone is signed in.
/// This one widget gives us login (1), logout (5) and persistent login (6):
///  - the first event of the auth stream is the session restored from the device,
///    so reopening the app lands on the home screen, not the login screen;
///  - signIn / signOut just change the stream, and this widget reacts.
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.auth,
    required this.repo,
    required this.themeController,
  });

  final AuthService auth;
  final DataRepository repo;
  final ThemeController themeController;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<String?> _authStream = widget.auth.authStateChanges();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: _authStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return EcoBackground(
            child: Center(child: CircularProgressIndicator(color: context.eco.accent)),
          );
        }
        final username = snapshot.data;
        if (username == null) {
          return LoginScreen(auth: widget.auth);
        }
        return HomeShell(
          auth: widget.auth,
          repo: widget.repo,
          username: username,
          theme: widget.themeController,
        );
      },
    );
  }
}
