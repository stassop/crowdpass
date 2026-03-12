import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// FirebaseAuth provider for dependency injection and easier testing
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Raw Firebase auth stream provider
/// Useful for simple "is logged in?" checks across the app
final authProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return auth.userChanges();
});

/// AuthNotifier
/// Handles authentication actions, loading states, error handling,
/// and syncing with the Firebase auth stream
class AuthNotifier extends AsyncNotifier<User?> {
  late final FirebaseAuth _auth;

  @override
  Future<User?> build() async {
    // Initialize FirebaseAuth from provider
    _auth = ref.read(firebaseAuthProvider);

    // Listen to the auth stream and sync notifier state
    ref.listen<AsyncValue<User?>>(authProvider, (previous, next) {
      next.whenData((user) {
        // Prevent overwriting manual loading or error states
        if (!state.isLoading && !state.hasError) {
          state = AsyncData(user);
        }
      });
    });

    // Return initial auth state
    return await ref.watch(authProvider.future);
  }

  /// Converts FirebaseAuthException codes into user-friendly messages
  String _handleError(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No user found for this email.';
        case 'wrong-password':
          return 'Incorrect password provided.';
        case 'invalid-credential':
          return 'Invalid email or password.';
        case 'email-already-in-use':
          return 'This email is already registered.';
        case 'invalid-email':
          return 'Invalid email address.';
        case 'weak-password':
          return 'Password is too weak.';
        case 'too-many-requests':
          return 'Too many attempts. Try again later.';
        default:
          return error.message ?? 'Authentication failed.';
      }
    }

    return 'An unexpected error occurred.';
  }

  /// Create a new user account
  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = const AsyncLoading();

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (displayName.isNotEmpty) {
        await credential.user?.updateDisplayName(displayName);
      }
      // Auth stream will update state automatically
    } catch (e, stackTrace) {
      state = AsyncError(_handleError(e), stackTrace);
    }
  }

  /// Sign in an existing user
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();

    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Auth stream will update state automatically
    } catch (e, stackTrace) {
      state = AsyncError(_handleError(e), stackTrace);
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    state = const AsyncLoading();

    try {
      await _auth.signOut();

      // Auth stream will emit null user automatically
    } catch (e, stackTrace) {
      state = AsyncError(_handleError(e), stackTrace);
    }
  }

  /// Update user profile information
  Future<void> updateUser({
    String? displayName,
    String? photoURL,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    state = const AsyncLoading();

    try {
      if (displayName != null) {
        await user.updateDisplayName(displayName);
      }

      if (photoURL != null) {
        await user.updatePhotoURL(photoURL);
      }

      await user.reload();

      // Force refresh because reload() may not immediately trigger userChanges()
      state = AsyncData(_auth.currentUser);
    } catch (e, stackTrace) {
      state = AsyncError(_handleError(e), stackTrace);
    }
  }
}

/// Global provider for AuthNotifier
final authNotifier =
    AsyncNotifierProvider<AuthNotifier, User?>(AuthNotifier.new);