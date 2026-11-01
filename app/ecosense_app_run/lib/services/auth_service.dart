/// Thrown when sign-in fails. [message] is safe to show to the user.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// What the rest of the app needs from "login". The screens only know this
/// interface, so they work the same with Firebase or with mock data.
abstract class AuthService {
  /// Emits the signed-in username, or null when signed out.
  /// The first event is the RESTORED session, which is what makes
  /// "stay signed in after closing the app" work.
  Stream<String?> authStateChanges();

  /// Throws [AuthFailure] when the username or password is wrong.
  Future<void> signIn(String username, String password);

  Future<void> signOut();
}
