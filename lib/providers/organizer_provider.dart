import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/providers/auth_provider.dart';
import 'package:crowdpass/providers/image_provider.dart'; // For handling image uploads

import 'package:crowdpass/models/organizer.dart'; // Ensure this model exists

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// 1. Data Stream Provider
/// Watches a specific organizer by ID.
final organizerProvider = StreamProvider.family<Organizer?, String>((ref, userId) {
  if (userId.isEmpty) return Stream.value(null);

  final firestore = ref.watch(firestoreProvider);

  return firestore.collection('organizers').doc(userId).snapshots().map((snapshot) {
    final data = snapshot.data();
    if (data == null || !snapshot.exists) return null;
    
    return Organizer.fromJson(data);
  });
});

/// 2. Organizer Action Notifier
/// Handles side effects (Create, Update, Delete) for Organizers.
class OrganizerAsyncNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    return;
  }

  /// Creates a new organizer profile.
  Future<void> createOrganizer(Organizer organizer, {String? logoURL}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await ref.read(authProvider.future);
      if (user == null) throw Exception('User must be authenticated.');

      final firestore = ref.read(firestoreProvider);

      if (logoURL != null) {
        // Optionally handle image upload and get the URL
        final uploadedLogoURL = await ref
            .read(imageProvider.notifier)
            .uploadImage(logoURL, 'images/${user.uid}');
        organizer = organizer.copyWith(logoURL: uploadedLogoURL);
      }
      
      // If organizer ID is meant to match user UID, use user.uid
      // Otherwise, let Firestore generate a random ID
      final docRef = firestore.collection('organizers').doc();
      final organizerWithId = organizer.copyWith(id: docRef.id);
      
      await docRef.set(organizerWithId.toJson());
    });
  }

  /// Updates organizer details.
  Future<void> updateOrganizer(Organizer organizer, {String? logoURL}) async {
    if (organizer.id == null || organizer.id!.isEmpty) {
      throw ArgumentError('Organizer ID is required for update.');
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await ref.read(authProvider.future);
      if (user == null) throw Exception('User must be authenticated.');

      final firestore = ref.read(firestoreProvider);
      final docRef = firestore.collection('organizers').doc(organizer.id);
      
      final snapshot = await docRef.get();
      if (!snapshot.exists) throw Exception('Organizer profile not found.');

      // Check permissions (e.g., only the owner or an admin can edit)
      final existingOrganizer = Organizer.fromJson(snapshot.data()!);
      if (existingOrganizer.id != user.uid) {
        throw Exception('You do not have permission to edit this profile.');
      }

      await docRef.update(organizer.toJson());
    });
  }

  /// Deletes an organizer profile.
  Future<void> deleteOrganizer(String organizerId) async {
    if (organizerId.isEmpty) throw ArgumentError('Organizer ID is required.');

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await ref.read(authProvider.future);
      if (user == null) throw Exception('User must be authenticated.');

      final firestore = ref.read(firestoreProvider);
      final docRef = firestore.collection('organizers').doc(organizerId);

      final snapshot = await docRef.get();
      if (!snapshot.exists) throw Exception('Organizer profile not found.');

      final existingOrganizer = Organizer.fromJson(snapshot.data()!);
      if (existingOrganizer.id != user.uid) {
        throw Exception('You do not have permission to delete this profile.');
      }

      await docRef.delete();
    });
  }
}

/// 3. Global Organizer Action Provider
final organizerNotifier = AsyncNotifierProvider<OrganizerAsyncNotifier, void>(() {
  return OrganizerAsyncNotifier();
});