import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:firebase_auth/firebase_auth.dart';

/// 1. The Raw Stream Provider
/// Good for simple "is logged in?" checks across the app.
final authProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.userChanges();
});

/// 2. The AuthNotifier
/// Manages the logic, loading states, and error handling.
/// Now simply returns User? (or null if not logged in).
class AuthNotifier extends AsyncNotifier<User?> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Future<User?> build() async {
    // We listen to the authProvider. When the stream emits a new user, 
    // we update this notifier's state, but ONLY if we aren't busy.
    ref.listen(authProvider, (previous, next) {
      next.whenData((user) {
        // This check is the "secret sauce" to prevent UI flickering.
        // It ensures a manual Error or Loading state isn't overwritten 
        // by the background stream immediately.
        if (!state.isLoading && !state.hasError) {
          state = AsyncData(user);
        }
      });
    });

    // Initial value for the notifier
    return await ref.watch(authProvider.future);
  }

  String _handleError(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found': return 'No user found for this email.';
        case 'wrong-password': return 'Incorrect password provided.';
        case 'invalid-credential': return 'Invalid email or password.';
        case 'too-many-requests': return 'Too many attempts. Try again later.';
        default: return error.message ?? 'Authentication failed.';
      }
    }
    return 'An unexpected error occurred.';
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      // We don't need to manually set AsyncData here; the ref.listen 
      // will pick up the success event from authProvider.
    } catch (e, stackTrace) {
      state = AsyncError(_handleError(e), stackTrace);
    }
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    try {
      await _auth.signOut();
    } catch (e, stackTrace) {
      state = AsyncError(_handleError(e), stackTrace);
    }
  }

  Future<void> updateUser({String? displayName, String? photoURL}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    state = const AsyncLoading();
    try {
      await user.updateProfile(displayName: displayName, photoURL: photoURL);
      await user.reload();
      // Manual sync here because reload() doesn't always trigger userChanges() immediately.
      state = AsyncData(_auth.currentUser);
    } catch (e, stackTrace) {
      state = AsyncError(_handleError(e), stackTrace);
    }
  }
}

/// Global provider for the AuthNotifier.
final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, User?>(() {
  return AuthNotifier();
});