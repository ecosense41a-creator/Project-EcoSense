import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/data_repository.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.auth, required this.repo});

  final AuthService auth;
  final DataRepository repo;

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness brightness) => ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.green,
            brightness: brightness,
          ),
        );

    return MaterialApp(
      title: 'EcoSense',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: AuthGate(auth: auth, repo: repo),
    );
  }
}

/// Decides which screen to show, based on whether someone is signed in.
/// This one widget gives us login (1), logout (5) and persistent login (6):
///  - the first event of the auth stream is the session restored from the device,
///    so reopening the app lands on the home screen, not the login screen;
///  - signIn / signOut just change the stream, and this widget reacts.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.auth, required this.repo});

  final AuthService auth;
  final DataRepository repo;

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
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final username = snapshot.data;
        if (username == null) {
          return LoginScreen(auth: widget.auth);
        }
        return HomeShell(auth: widget.auth, repo: widget.repo, username: username);
      },
    );
  }
}
