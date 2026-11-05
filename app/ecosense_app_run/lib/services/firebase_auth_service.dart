
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_service.dart';

/// Signs users in and out through Firebase Authentication.
class FirebaseAuthService implements AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Stream<String?> authStateChanges() {
    return _auth.authStateChanges().map(
      (user) => user?.email,
    );
  }

  @override
  String? get currentUid => _auth.currentUser?.uid;

  @override
  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_friendlyMessage(e.code));
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }

  String _friendlyMessage(String code) {
    switch (code) {
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return 'Incorrect email or password.';

      case 'invalid-email':
        return 'Please enter a valid email address.';

      case 'user-disabled':
        return 'This account has been disabled.';

      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';

      case 'network-request-failed':
        return 'Network error. Check your internet connection.';

      default:
        return 'Firebase Authentication error: $code';
    }
  }
}
