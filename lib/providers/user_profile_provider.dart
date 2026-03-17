import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:crowdpass/providers/auth_provider.dart'; 
import 'package:crowdpass/providers/firestore_provider.dart';
import 'package:crowdpass/models/user_profile.dart';
import 'package:crowdpass/models/country.dart';

/// Unified provider for fetching profile data.
final userProfileProvider = StreamProvider.family<UserProfile?, String?>((ref, userId) {
  final firestore = ref.watch(firestoreProvider);
  
  // Watch only the UID to avoid unnecessary rebuilds if other User properties change
  final currentUserUid = ref.watch(authProvider.select((s) => s.value?.uid));

  final String? effectiveId = (userId == null || userId.isEmpty) ? currentUserUid : userId;

  if (effectiveId == null) {
    return Stream.value(null);
  }

  return firestore
      .collection('users')
      .doc(effectiveId)
      .snapshots()
      .map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) return null;
        
        // Ensure the ID is injected if your model expects it
        final data = snapshot.data()!;
        return UserProfile.fromJson({...data, 'uid': snapshot.id});
      });
});

class UserProfileNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async => null; // No initial data, just manage loading/error states

  /// Private helper to get the UID without waiting for the Auth Stream
  String _requireUserId() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User must be logged in to perform this action.');
    return user.uid;
  }

  Future<void> createUserProfile({
    required String displayName,
    required String email,
    required String phone,
    required Country country,
    String? photoURL,
  }) async {
    state = const AsyncLoading();
    try {
      final uid = _requireUserId();
      final userProfile = UserProfile(
        uid: uid,
        displayName: displayName,
        email: email, 
        phone: phone,
        country: country,
        photoURL: photoURL,
      );

      await ref
          .read(firestoreProvider)
          .collection('users')
          .doc(uid)
          .set(userProfile.toJson(), SetOptions(merge: true)); // Use merge for safety
          
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> updateUserProfile({
    String? displayName,
    String? photoURL,
    String? email,
    String? phone,
    Country? country,
  }) async {
    state = const AsyncLoading();
    try {
      final uid = _requireUserId();
      final updates = <String, dynamic>{
        if (displayName != null) 'displayName': displayName,
        if (photoURL != null) 'photoURL': photoURL,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        if (country != null) 'country': country.toJson(),
        'updatedAt': FieldValue.serverTimestamp(), // Good practice
      };

      if (updates.isNotEmpty) {
        await ref
            .read(firestoreProvider)
            .collection('users')
            .doc(uid)
            .update(updates);
      }
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> deleteUserProfile() async {
    state = const AsyncLoading();
    try {
      final uid = _requireUserId();
      await ref.read(firestoreProvider).collection('users').doc(uid).delete();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final userProfileNotifier =
    AsyncNotifierProvider<UserProfileNotifier, void>(UserProfileNotifier.new);