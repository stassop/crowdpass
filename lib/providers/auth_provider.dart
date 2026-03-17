import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Assuming these are your actual provider paths
import 'package:crowdpass/providers/user_profile_provider.dart';
import 'package:crowdpass/models/country.dart';

import 'package:crowdpass/services/image_service.dart';

/// Provides the Firebase Auth instance
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

/// A stream of the current user's authentication state.
/// Use this in the UI to determine if the user is logged in.
final authProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// The main Notifier managing authentication logic AND state.
/// State = current Firebase [User] or null (unauthenticated)
class AuthNotifier extends AsyncNotifier<User?> {
  StreamSubscription<User?>? _authSub;

  @override
  Future<User?> build() async {
    final auth = ref.read(firebaseAuthProvider);

    // Listen to Firebase auth state changes
    _authSub = auth.authStateChanges().listen((user) {
      state = AsyncData(user);
    });

    // Clean up
    ref.onDispose(() {
      _authSub?.cancel();
    });

    // Initial value
    return auth.currentUser;
  }

  /// Create account + Create Firestore Profile
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

    try {
      // 1. Create Auth User
      credential = await ref
          .read(firebaseAuthProvider)
          .createUserWithEmailAndPassword(email: email, password: password);

      final user = credential.user;
      if (user == null) throw Exception('User creation failed.');

      // 2. Upload Image (if any)
      String? uploadedPhotoURL;
      if (photoPath != null && photoPath.isNotEmpty) {
        uploadedPhotoURL = await ImageFileService.uploadImage(
          photoPath,
          'users/${user.uid}/profile_photo',
        );
      }

      // // 3. Update Firebase Auth profile
      await Future.wait([
        user.updateDisplayName(displayName),
        if (uploadedPhotoURL != null) user.updatePhotoURL(uploadedPhotoURL),
      ]);

      // 4. Create Firestore profile
      await ref
          .read(userProfileNotifier.notifier)
          .createUserProfile(
            displayName: displayName,
            photoURL: uploadedPhotoURL,
            email: email,
            phone: phone,
            country: country,
          );

      // Ensure fresh user data
      await user.reload();
      final updatedUser = ref.read(firebaseAuthProvider).currentUser;

      state = AsyncData(updatedUser);
    } catch (e, st) {
      // Rollback if needed
      if (credential?.user != null) {
        await credential!.user!.delete();
      }

      state = AsyncError(_handleError(e), st);
      rethrow;
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();

    try {
      final credential = await ref
          .read(firebaseAuthProvider)
          .signInWithEmailAndPassword(email: email, password: password);

      state = AsyncData(credential.user);
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
      // Sensitive update
      if (password != null && password.isNotEmpty) {
        await user.updatePassword(password);
      }

      // Upload new image if needed
      String? newPhotoURL;
      if (photoPath != null && photoPath.isNotEmpty) {
        newPhotoURL = await ImageFileService.uploadImage(
          photoPath,
          'users/${user.uid}/profile_photo',
        );
      }

      // Update Firebase Auth profile
      if (displayName != null) {
        await user.updateDisplayName(displayName);
      }
      if (newPhotoURL != null) {
        await user.updatePhotoURL(newPhotoURL);
      }

      // Sync Firestore
      await ref
          .read(userProfileNotifier.notifier)
          .updateUserProfile(
            displayName: displayName,
            photoURL: newPhotoURL,
            phone: phone,
            country: country,
          );

      await user.reload();
      final updatedUser = ref.read(firebaseAuthProvider).currentUser;

      state = AsyncData(updatedUser);
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
      // Delete Firestore first
      await ref.read(userProfileNotifier.notifier).deleteUserProfile();

      // Delete Auth account
      await user.delete();

      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(_handleError(e), st);
      rethrow;
    }
  }

  String _handleError(dynamic error) {
    if (error is FirebaseAuthException) {
      final map = {
        'user-not-found': 'No account found with this email.',
        'wrong-password': 'Incorrect password.',
        'email-already-in-use': 'This email is already registered.',
        'weak-password': 'The password is too weak.',
        'requires-recent-login': 'Security: Please log out and back in.',
        'network-request-failed': 'Please check your internet connection.',
      };

      return map[error.code] ?? 'Authentication error: ${error.message}';
    }

    return error.toString().replaceAll('Exception:', '').trim();
  }
}

/// Global provider
final authNotifier = AsyncNotifierProvider<AuthNotifier, User?>(
  AuthNotifier.new,
);
