/// Thrown when sign-in fails. [message] is safe to show to the user.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Defines the sign-in operations used by the app screens.
abstract class AuthService {
  /// Emits the signed-in email, or null when signed out.
  /// The first event is the RESTORED session, which is what makes
  /// "stay signed in after closing the app" work.
  Stream<String?> authStateChanges();

  /// Stable id of the signed-in user (used for per-user settings in
  /// /users/<uid>). Null when signed out.
  String? get currentUid;

  /// Throws [AuthFailure] when the email or password is wrong.
  Future<void> signIn(String email, String password);

  Future<void> signOut();
}
