import 'package:flutter/widgets.dart';

import 'services/auth_service.dart';
import 'services/data_repository.dart';
import 'theme/theme_controller.dart';

/// What every signed-in screen needs. Sheets are shown on a route that is NOT
/// below this widget, so they receive the scope as a constructor argument.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.auth,
    required this.repo,
    required this.username,
    required this.uid,
    required this.serverOffsetMs,
    required this.theme,
    required super.child,
  });

  final AuthService auth;
  final DataRepository repo;
  final String username;
  final String uid;

  /// Firebase clock minus phone clock (ms).
  final int serverOffsetMs;
  final ThemeController theme;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope above this widget');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope old) =>
      old.serverOffsetMs != serverOffsetMs || old.username != username || old.uid != uid;
}
