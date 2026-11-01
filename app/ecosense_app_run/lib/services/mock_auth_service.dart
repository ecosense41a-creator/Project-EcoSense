import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import 'auth_service.dart';

/// Fake login for development. Accepts only kMockUsername / kMockPassword.
/// The session is saved with shared_preferences, so persistent login can be
/// tested: sign in, fully close the app, reopen it, and you are still signed in.
class MockAuthService implements AuthService {
  static const String _prefsKey = 'mock_session_username';

  final StreamController<String?> _controller =
      StreamController<String?>.broadcast();
  SharedPreferences? _prefs;
  String? _current;

  /// Must be awaited once before the app starts (loads the saved session).
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _current = _prefs!.getString(_prefsKey);
  }

  @override
  Stream<String?> authStateChanges() async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  Future<void> signIn(String username, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 600)); // fake network
    if (username.trim() == kMockUsername && password == kMockPassword) {
      _current = kMockUsername;
      await _prefs?.setString(_prefsKey, kMockUsername);
      _controller.add(_current);
    } else {
      throw const AuthFailure('Incorrect username or password.');
    }
  }

  @override
  Future<void> signOut() async {
    _current = null;
    await _prefs?.remove(_prefsKey);
    _controller.add(null);
  }
}
