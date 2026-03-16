import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Assuming authProvider is the StreamProvider<User?> from your auth file
import 'package:crowdpass/providers/auth_provider.dart';
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
  final authState = ref.watch(authProvider);

  // If no userId is provided, we reactively watch the current Auth state
  final String? effectiveId = (userId == null || userId.isEmpty)
      ? authState.value?.uid
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
    // If document doesn't exist or data is null, return null
    if (data == null || !snapshot.exists) return null;
    
    // This will now throw an error if the Firestore data is missing 
    // any of the required fields (phone, country, email, etc.)
    return UserProfile.fromJson(data);
  });
});

/// Auxiliary Notifier strictly for Firestore CRUD operations.
class UserProfileAsyncNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    return;
  }

  /// Only handles the creation of the Firestore Document.
  /// Updated to require all non-nullable fields defined in UserProfile.
  Future<void> createUserProfile({
    required String displayName,
    required String email,
    required String phone,
    required Country country,
    String? photoURL,
  }) async {
    final user = ref.read(authProvider).value;
    if (user == null) throw Exception('No authenticated user found.');

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
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
    });
  }

  /// Only updates fields in the Firestore 'users' collection.
  /// Uses a Map for partial updates, so we don't need the full Model here.
  Future<void> updateUserProfile({
    String? displayName,
    String? photoURL,
    String? email,
    String? phone,
    Country? country,
  }) async {
    final user = ref.read(authProvider).value;
    if (user == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
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
    });
  }

  /// Only deletes the Firestore document.
  Future<void> deleteUserProfile() async {
    final user = ref.read(authProvider).value;
    if (user == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(firestoreProvider)
          .collection('users')
          .doc(user.uid)
          .delete();
    });
  }
}

final userProfileNotifier =
    AsyncNotifierProvider<UserProfileAsyncNotifier, void>(
      UserProfileAsyncNotifier.new,
    );