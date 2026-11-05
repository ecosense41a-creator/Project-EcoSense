import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light / Dark / System. Cached on the phone (so the login screen and the
/// first frame use it) and synced to /users/<uid>/prefs/theme after sign-in.
class ThemeController extends ChangeNotifier {
  static const String _key = 'ecosense_theme';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  /// "light" | "dark" | "system"
  String get value => _mode.name;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _mode = _parse(prefs.getString(_key));
    } catch (_) {
      _mode = ThemeMode.system;
    }
  }

  /// Returns true if the value actually changed.
  bool set(String value) {
    final next = _parse(value);
    if (next == _mode) return false;
    _mode = next;
    notifyListeners();
    SharedPreferences.getInstance().then((p) => p.setString(_key, next.name)).catchError((_) => false);
    return true;
  }

  static ThemeMode _parse(String? v) => switch (v) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}
