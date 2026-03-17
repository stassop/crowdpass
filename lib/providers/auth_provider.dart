import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Ensure these paths match your project structure
import 'package:crowdpass/providers/user_profile_provider.dart';
import 'package:crowdpass/providers/image_provider.dart';

import 'package:crowdpass/models/country.dart';

/// Provides the Firebase Auth instance
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

/// A stream of the current user's authentication state for the UI to listen to.
final authProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).userChanges();
});

/// The main Notifier managing authentication logic and state
class AuthNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    // No initial state to load here; kept for possible future initialization.
  }

  /// Create account + Create Firestore Profile
  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
    required String phone,
    required Country country,
    String? photoURL,
  }) async {
    state = const AsyncLoading();
    User? user;

    try {
      final credential = await ref
          .read(firebaseAuthProvider)
          .createUserWithEmailAndPassword(email: email, password: password);
      user = credential.user;

      if (user == null) {
        // Defensive: handle unexpected null user
        state = AsyncError('Failed to create user.', StackTrace.current);
        return;
      }

      // 1. Update Auth Profile
      await user.updateDisplayName(displayName);

      // 2. Handle Image Upload if necessary
      String? uploadedPhotoURL;
      if (photoURL != null && photoURL.isNotEmpty) {
        uploadedPhotoURL = await ref
            .read(imageNotifier.notifier)
            .uploadImage(photoURL, 'users/${user.uid}/photo');
      }

      if (uploadedPhotoURL != null) {
        await user.updatePhotoURL(uploadedPhotoURL);
      }

      // 3. Create the Firestore profile
      await ref.read(userProfileNotifier.notifier).createUserProfile(
            displayName: displayName,
            photoURL: uploadedPhotoURL,
            email: email,
            phone: phone,
            country: country,
          );

      state = const AsyncData(null);
    } catch (e, st) {
      // CLEANUP: If Auth succeeded but Firestore/Image failed, try deleting the auth user
      if (user != null) {
        try {
          await user.delete();
        } catch (_) {
          // Deletion may fail (e.g., requires recent login); don't mask the original error.
        }
      }

      final errorMessage = _handleError(e);
      state = AsyncError(errorMessage, st);
      rethrow; // Rethrow so the UI can catch it for SnackBars/Dialogs if desired
    }
  }

  /// Update Auth + Update Firestore Profile
  Future<void> updateUser({
    String? displayName,
    String? photoURL,
    String? password,
    String? phone,
    Country? country,
  }) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;

    state = const AsyncLoading();

    try {
      if (password != null && password.isNotEmpty) {
        await user.updatePassword(password);
      }

      if (displayName != null && displayName.isNotEmpty) {
        await user.updateDisplayName(displayName);
      }

      String? uploadedPhotoURL;
      if (photoURL != null && photoURL.isNotEmpty) {
        uploadedPhotoURL = await ref
            .read(imageNotifier.notifier)
            .uploadImage(photoURL, 'users/${user.uid}/photo');
        if (uploadedPhotoURL != null) {
          await user.updatePhotoURL(uploadedPhotoURL);
        }
      }

      // Sync changes to Firestore
      await ref.read(userProfileNotifier.notifier).updateUserProfile(
            displayName: displayName,
            photoURL: uploadedPhotoURL,
            phone: phone,
            country: country,
          );

      await user.reload();
      // AuthNotifier is typed as void, so return AsyncData(null)
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(_handleError(e), st);
      rethrow;
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(firebaseAuthProvider)
          .signInWithEmailAndPassword(email: email, password: password);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(_handleError(e), st);
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    try {
      await ref.read(firebaseAuthProvider).signOut();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(_handleError(e), st);
      rethrow;
    }
  }

  Future<void> reauthenticate(String email, String password) async {
    state = const AsyncLoading();
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await ref
          .read(firebaseAuthProvider)
          .currentUser
          ?.reauthenticateWithCredential(credential);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(_handleError(e), st);
      rethrow;
    }
  }

  Future<void> deleteUser() async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;

    state = const AsyncLoading();
    try {
      // Delete Firestore data before Auth account
      await ref.read(userProfileNotifier.notifier).deleteUserProfile();
      await user.delete();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(_handleError(e), st);
      rethrow;
    }
  }

  String _handleError(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        // Sign in / account errors
        case 'user-not-found':
          return 'No account found with this email.';
        case 'wrong-password':
          return 'Incorrect password.';
        case 'invalid-credential':
          return 'Invalid login credentials.';
        case 'user-disabled':
          return 'This account has been disabled.';

        // Email errors
        case 'invalid-email':
          return 'The email address is not valid.';
        case 'email-already-in-use':
        case 'email-already-exists':
          return 'This email is already registered.';

        // Password errors
        case 'weak-password':
          return 'The password is too weak.';

        // Credential / provider issues
        case 'account-exists-with-different-credential':
          return 'An account already exists with a different sign-in method.';
        case 'credential-already-in-use':
          return 'This credential is already associated with another account.';
        case 'operation-not-allowed':
          return 'This sign-in method is not enabled.';

        // Phone auth
        case 'invalid-verification-code':
          return 'The verification code is invalid.';
        case 'invalid-verification-id':
          return 'The verification session has expired. Please try again.';

        // Security / re-auth
        case 'requires-recent-login':
          return 'Please re-login to perform this action.';

        // Network / rate limiting
        case 'network-request-failed':
          return 'Network error. Check your connection.';
        case 'too-many-requests':
          return 'Too many attempts. Try again later.';

        // Fallback
        default:
          return 'Authentication failed. Please try again.';
      }
    }

    final message = error.toString();

    if (message.contains('Exception:')) {
      return message.split('Exception:').last.trim();
    }

    return 'An unexpected error occurred.';
  }
}

/// The global provider for the AuthNotifier
final authNotifier = AsyncNotifierProvider<AuthNotifier, void>(
  AuthNotifier.new,
);