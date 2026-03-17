import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Assuming these are your actual provider paths
import 'package:crowdpass/providers/user_profile_provider.dart';
import 'package:crowdpass/providers/image_provider.dart';
import 'package:crowdpass/models/country.dart';

/// Provides the Firebase Auth instance
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

/// A stream of the current user's authentication state.
/// Use this in the UI to determine if the user is logged in.
final authProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// The main Notifier managing authentication logic and state.
/// Typed as <void> because we only care about the loading/error status of the actions.
class AuthNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    // Initial state is 'null' (data)
    return;
  }

  /// Create account + Create Firestore Profile
  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
    required String phone,
    required Country country,
    String? photoPath, // Changed name to imply local path vs URL
  }) async {
    state = const AsyncLoading();
    
    UserCredential? credential;
    try {
      // 1. Create Auth User
      credential = await ref.read(firebaseAuthProvider).createUserWithEmailAndPassword(
        email: email, 
        password: password,
      );

      final user = credential.user;
      if (user == null) throw Exception('User creation failed.');

      // 2. Upload Image (if any)
      String? finalPhotoURL;
      if (photoPath != null && photoPath.isNotEmpty) {
        finalPhotoURL = await ref
            .read(imageNotifier.notifier)
            .uploadImage(photoPath, 'users/${user.uid}/profile_photo');
      }

      // 3. Update Firebase Auth Profile (DisplayName & Photo)
      // We do this in parallel to save time
      await Future.wait([
        user.updateDisplayName(displayName),
        if (finalPhotoURL != null) user.updatePhotoURL(finalPhotoURL),
      ]);

      // 4. Create the Firestore profile
      // It's vital to wait for this to succeed
      await ref.read(userProfileNotifier.notifier).createUserProfile(
            displayName: displayName,
            photoURL: finalPhotoURL,
            email: email,
            phone: phone,
            country: country,
          );

      state = const AsyncData(null);
    } catch (e, st) {
      // ROLLBACK: If Firestore/Image fails, delete the Auth account to prevent "ghost" users
      if (credential?.user != null) {
        await credential!.user!.delete();
      }
      
      state = AsyncError(_handleError(e), st);
      rethrow; 
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => 
      ref.read(firebaseAuthProvider).signInWithEmailAndPassword(email: email, password: password)
    );
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(firebaseAuthProvider).signOut());
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
      // Handle sensitive updates
      if (password != null && password.isNotEmpty) {
        await user.updatePassword(password);
      }

      String? newPhotoURL;
      if (photoPath != null && photoPath.isNotEmpty) {
        newPhotoURL = await ref
            .read(imageNotifier.notifier)
            .uploadImage(photoPath, 'users/${user.uid}/profile_photo');
      }

      // Update Auth Profile
      if (displayName != null) await user.updateDisplayName(displayName);
      if (newPhotoURL != null) await user.updatePhotoURL(newPhotoURL);

      // Sync to Firestore
      await ref.read(userProfileNotifier.notifier).updateUserProfile(
            displayName: displayName,
            photoURL: newPhotoURL,
            phone: phone,
            country: country,
          );

      await user.reload();
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
      // 1. Delete Firestore Data first (while Auth is still valid)
      await ref.read(userProfileNotifier.notifier).deleteUserProfile();
      // 2. Delete Auth Account
      await user.delete();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(_handleError(e), st);
      rethrow;
    }
  }

  String _handleError(dynamic error) {
    if (error is FirebaseAuthException) {
      // Map specific Firebase codes to user-friendly messages
      final map = {
        'user-not-found': 'No account found with this email.',
        'wrong-password': 'Incorrect password.',
        'email-already-in-use': 'This email is already registered.',
        'weak-password': 'The password is too weak.',
        'requires-recent-login': 'Security: Please log out and back in to delete your account.',
        'network-request-failed': 'Please check your internet connection.',
      };
      return map[error.code] ?? 'Authentication error: ${error.message}';
    }
    return error.toString().replaceAll('Exception:', '').trim();
  }
}

/// The global provider for the AuthNotifier
final authNotifier = AsyncNotifierProvider<AuthNotifier, void>(AuthNotifier.new);