import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Assuming authProvider is the StreamProvider<User?> from your auth file
import 'package:crowdpass/providers/auth_provider.dart'; // Update to your actual path

import 'package:crowdpass/models/user_profile.dart';
import 'package:crowdpass/models/country.dart';

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

/// Unified provider: Pass a userId to fetch a specific profile,
/// or null/empty string to fetch the currently authenticated user's profile.
final userProfileProvider = StreamProvider.family<UserProfile?, String?>((
  ref,
  userId,
) {
  final firestore = ref.watch(firestoreProvider);
  
  // Optimization: Only listen to changes in the UID, not the whole User object.
  final currentUid = ref.watch(authProvider.select((s) => s.value?.uid));

  final String? effectiveId = (userId == null || userId.isEmpty)
      ? currentUid
      : userId;

  if (effectiveId == null) {
    return Stream.value(null);
  }

  return firestore
      .collection('users')
      .doc(effectiveId)
      .snapshots()
      .map((snapshot) {
    final data = snapshot.data();
    if (data == null || !snapshot.exists) return null;
    
    // Returns the model. If fields are missing, the Stream will emit an AsyncError.
    return UserProfile.fromJson(data);
  });
});

/// Auxiliary Notifier strictly for Firestore CRUD operations.
class UserProfileAsyncNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    return;
  }

  /// Creates the Firestore Document.
  Future<void> createUserProfile({
    required String displayName,
    required String email,
    required String phone,
    required Country country,
    String? photoURL,
  }) async {
    final user = await ref.read(authProvider.future);
    if (user == null) throw Exception('Authenticated user not found.');

    state = const AsyncLoading();
    try {
      final userProfile = UserProfile(
        uid: user.uid,
        displayName: displayName,
        email: email, 
        phone: phone,
        country: country,
        photoURL: photoURL,
      );

      await ref
          .read(firestoreProvider)
          .collection('users')
          .doc(user.uid)
          .set(userProfile.toJson());
          
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Updates fields in the Firestore 'users' collection.
  Future<void> updateUserProfile({
    String? displayName,
    String? photoURL,
    String? email,
    String? phone,
    Country? country,
  }) async {
    final user = await ref.read(authProvider.future);
    if (user == null) throw Exception('Authenticated user not found.');

    state = const AsyncLoading();
    try {
      final updates = <String, dynamic>{
        if (displayName != null) 'displayName': displayName,
        if (photoURL != null) 'photoURL': photoURL,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        if (country != null) 'country': country.toJson(),
      };

      if (updates.isNotEmpty) {
        await ref
            .read(firestoreProvider)
            .collection('users')
            .doc(user.uid)
            .update(updates);
      }
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Deletes the Firestore document.
  Future<void> deleteUserProfile() async {
    final user = await ref.read(authProvider.future);
    if (user == null) throw Exception('Authenticated user not found.');

    state = const AsyncLoading();
    try {
      await ref
          .read(firestoreProvider)
          .collection('users')
          .doc(user.uid)
          .delete();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final userProfileNotifier =
    AsyncNotifierProvider<UserProfileAsyncNotifier, void>(
      UserProfileAsyncNotifier.new,
    );