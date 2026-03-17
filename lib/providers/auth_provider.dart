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

/// A stream of the current user's authentication state.
final authProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).userChanges();
});

/// The main Notifier managing authentication logic and state
class AuthNotifier extends AsyncNotifier<User?> {
  late final FirebaseAuth _auth;

  @override
  Future<User?> build() async {
    // We watch the instance so the notifier is reactive to the provider itself
    _auth = ref.watch(firebaseAuthProvider);

    // Automatically update state whenever the Firebase User changes (login/logout/token change)
    return ref.watch(authProvider.future);
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

    state = await AsyncValue.guard(() async {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        await user.updateDisplayName(displayName);

        String? uploadedPhotoURL;
        if (photoURL != null && photoURL.isNotEmpty) {
          uploadedPhotoURL = await ref
              .read(imageNotifier.notifier)
              .uploadImage(photoURL, 'users/${user.uid}/photo');
        }

        if (uploadedPhotoURL != null) {
          await user.updatePhotoURL(uploadedPhotoURL);
        }

        // Create the Firestore profile
        // FIX: Pass the UID directly instead of waiting for the provider to update
        await ref.read(userProfileNotifier.notifier).createUserProfile(
              uid: user.uid,
              displayName: displayName,
              photoURL: uploadedPhotoURL,
              email: email,
              phone: phone,
              country: country,
            );

        final profileState = ref.read(userProfileNotifier);
        if (profileState.hasError) {
          throw profileState.error!;
        }
      }
      return _auth.currentUser;
    });

    if (state.hasError) {
      state = AsyncError(_handleError(state.error), state.stackTrace!);
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
    final user = _auth.currentUser;
    if (user == null) return;

    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
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
      }

      if (uploadedPhotoURL != null) await user.updatePhotoURL(uploadedPhotoURL);

      // Sync changes to Firestore
      // FIX: Pass the UID directly
      await ref.read(userProfileNotifier.notifier).updateUserProfile(
            uid: user.uid,
            displayName: displayName,
            photoURL: uploadedPhotoURL,
            phone: phone,
            country: country,
          );

      final profileState = ref.read(userProfileNotifier);
      if (profileState.hasError) {
        throw profileState.error!;
      }

      await user.reload();
      return _auth.currentUser;
    });

    if (state.hasError) {
      state = AsyncError(_handleError(state.error), state.stackTrace!);
    }
  }

  /// Specifically for handling "requires-recent-login" errors
  Future<void> reauthenticate(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final credential = EmailAuthProvider.credential(email: email, password: password);
      await _auth.currentUser?.reauthenticateWithCredential(credential);
      return _auth.currentUser;
    });

    if (state.hasError) {
      state = AsyncError(_handleError(state.error), state.stackTrace!);
    }
  }

  /// Delete Firestore Profile + Delete Auth Account
  Future<void> deleteUser() async {
    final user = _auth.currentUser;
    if (user == null) return;

    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      // FIX: Pass UID directly
      await ref.read(userProfileNotifier.notifier).deleteUserProfile(uid: user.uid);
      await user.delete();
      return null;
    });

    if (state.hasError) {
      state = AsyncError(_handleError(state.error), state.stackTrace!);
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return _auth.currentUser;
    });

    if (state.hasError) {
      state = AsyncError(_handleError(state.error), state.stackTrace!);
    }
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _auth.signOut();
      return null;
    });

    if (state.hasError) {
      state = AsyncError(_handleError(state.error), state.stackTrace!);
    }
  }

  String _handleError(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No account found with this email.';
        case 'wrong-password':
          return 'Incorrect password. Please try again.';
        case 'email-already-in-use':
          return 'This email is already registered.';
        case 'weak-password':
          return 'The password provided is too weak.';
        case 'invalid-email':
          return 'The email address is not valid.';
        case 'requires-recent-login':
          return 'Security check: Please re-login to perform this action.';
        case 'network-request-failed':
          return 'Network error. Please check your connection.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        default:
          return error.message ?? 'An authentication error occurred.';
      }
    }
    return 'An unexpected error occurred. Please try again.';
  }
}

/// The global provider for the AuthNotifier
final authNotifier = AsyncNotifierProvider<AuthNotifier, User?>(
  AuthNotifier.new,
);