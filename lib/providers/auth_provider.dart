import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:crowdpass/providers/user_profile_provider.dart';
import 'package:crowdpass/models/country.dart';
import 'package:crowdpass/services/image_file_service.dart';

/// Firebase Auth provider
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

/// Stream provider to listen to auth state changes.
/// This is the SINGLE SOURCE OF TRUTH for "Who is the current user?".
final authProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).userChanges();
});

/// Auth Notifier for performing actions (Sign In, Sign Up, Update, Delete).
/// This tracks the STATE OF THE ACTION (Loading, Success, Error), not the user data.
class AuthNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// SIGN UP
  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
    required String phone,
    required Country country,
    String? photoPath,
  }) async {
    state = const AsyncLoading();

    UserCredential? credential;
    String? uploadedPhotoURL;

    try {
      credential = await ref
          .read(firebaseAuthProvider)
          .createUserWithEmailAndPassword(
            email: email,
            password: password,
          );

      final user = credential.user;
      if (user == null) throw Exception('User creation failed.');

      /// IMPORTANT: Force token refresh to ensure new user has valid token for storage operations.
      await user.getIdToken(true);

      // Upload image
      if (photoPath != null && photoPath.isNotEmpty) {
        uploadedPhotoURL = await ImageFileService.uploadImage(
          photoPath,
          'users/${user.uid}/profile_photo',
        );
      }
      
      await Future.wait([
        user.updateDisplayName(displayName),
        if (uploadedPhotoURL != null) user.updatePhotoURL(uploadedPhotoURL),
      ]);

      // Optional: Email verification
      await user.sendEmailVerification();

      await ref.read(userProfileNotifier.notifier).createUserProfile(
            displayName: displayName,
            photoURL: uploadedPhotoURL,
            email: email,
            phone: phone,
            country: country,
          );

      // Refresh user to ensure Firebase Auth updates locally
      await user.reload();
      
      state = const AsyncData(null);
    } catch (e, st) {
      debugPrint('signUp error: $e\n$st');

      // Rollback: delete uploaded image
      if (uploadedPhotoURL != null) {
        try {
          await ImageFileService.deleteImage(uploadedPhotoURL);
        } catch (_) {}
      }

      // Rollback: delete auth user
      if (credential?.user != null) {
        await credential!.user!.delete();
      }

      state = AsyncError(_handleError(e), st);
    }
  }

  /// SIGN IN
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();

    try {
      await ref
          .read(firebaseAuthProvider)
          .signInWithEmailAndPassword(
            email: email,
            password: password,
          );

      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(_handleError(e), st);
    }
  }

  /// SIGN OUT
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

  /// UPDATE USER
  Future<void> updateUser({
    String? displayName,
    String? photoPath,
    String? password,
    String? phone,
    Country? country,
  }) async {
    final user = ref.read(firebaseAuthProvider).currentUser;

    if (user == null) {
      state = AsyncError('No user logged in', StackTrace.current);
      return;
    }

    state = const AsyncLoading();

    try {
      await user.getIdToken(true);

      if (password != null && password.isNotEmpty) {
        await user.updatePassword(password);
      }

      String? newPhotoURL;
      if (photoPath != null && photoPath.isNotEmpty) {
        newPhotoURL = await ImageFileService.uploadImage(
          photoPath,
          'users/${user.uid}/profile_photo',
        );
      }

      if (displayName != null) {
        await user.updateDisplayName(displayName);
      }
      if (newPhotoURL != null) {
        await user.updatePhotoURL(newPhotoURL);
      }

      await ref.read(userProfileNotifier.notifier).updateUserProfile(
            displayName: displayName,
            photoURL: newPhotoURL,
            phone: phone,
            country: country,
          );

      await user.reload();
      state = const AsyncData(null);
    } catch (e, st) {
      if (e is FirebaseAuthException && e.code == 'requires-recent-login') {
        debugPrint('Re-authentication required');
      }

      state = AsyncError(_handleError(e), st);
      rethrow;
    }
  }

  /// DELETE USER
  Future<void> deleteUser() async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;

    state = const AsyncLoading();

    try {
      await ref.read(userProfileNotifier.notifier).deleteUserProfile();
      await user.delete();

      state = const AsyncData(null);
    } catch (e, st) {
      if (e is FirebaseAuthException && e.code == 'requires-recent-login') {
        debugPrint('Re-authentication required before deletion');
      }

      state = AsyncError(_handleError(e), st);
      rethrow;
    }
  }

  /// ERROR HANDLER
  String _handleError(dynamic error) {
    if (error is FirebaseAuthException) {
      const map = {
        'user-not-found': 'No account found with this email.',
        'wrong-password': 'Incorrect password.',
        'email-already-in-use': 'This email is already registered.',
        'weak-password': 'The password is too weak.',
        'requires-recent-login': 'Please re-authenticate to continue.',
        'network-request-failed': 'Check your internet connection.',
      };

      return map[error.code] ??
          'Authentication error: ${error.message}';
    }

    return error.toString().replaceAll('Exception:', '').trim();
  }
}

/// Global provider
final authNotifier =
    AsyncNotifierProvider<AuthNotifier, void>(
  AuthNotifier.new,
);