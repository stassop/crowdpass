import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Assuming these paths based on your previous snippet
import 'package:crowdpass/providers/auth_provider.dart';
import 'package:crowdpass/providers/company_provider.dart';

import 'package:crowdpass/models/event.dart';

/// 1. Dependency Providers
/// Providing the instance allows for easy mocking during unit tests.
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// 2. Data Stream Provider
/// Watches a specific event by ID. 
/// Using .family allows you to pass the eventId as a parameter.
final eventProvider = StreamProvider.family<Event?, String?>((ref, eventId) {
  if (eventId == null || eventId.isEmpty) return Stream.value(null);

  final firestore = ref.watch(firestoreProvider);

  return firestore.collection('events').doc(eventId).snapshots().map((snapshot) {
    final data = snapshot.data();
    if (data == null || !snapshot.exists) return null;
    
    // Ensure the model handles the incoming ID from Firestore if necessary
    return Event.fromJson(data);
  });
});

/// 3. Event Action Notifier
/// Handles side effects (Create, Update, Delete).
/// Inheriting from AsyncNotifier<void> allows us to track the loading/error 
/// state of these asynchronous operations.
class EventAsyncNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    // No initial state needed for a void action notifier
    return;
  }

  /// Creates a new event and automatically assigns the Firestore Doc ID.
  Future<void> createEvent(Event event) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await ref.read(authProvider.future);
      if (user == null) throw Exception('User must be authenticated to create an event.');

      final isOrganizer = await ref.read(companyProvider(user.uid).future) != null;
      if (!isOrganizer) throw Exception('Only organizers can create events.');

      final firestore = ref.read(firestoreProvider);
      final docRef = firestore.collection('events').doc();
      
      // Sync the Firestore ID with the model ID before saving
      final eventWithId = event.copyWith(id: docRef.id);
      await docRef.set(eventWithId.toJson());
    });
  }

  /// Updates an existing event.
  Future<void> updateEvent(Event event) async {
    if (event.id == null || event.id!.isEmpty) {
      throw ArgumentError('Event ID cannot be null or empty for updates.');
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await ref.read(authProvider.future);
      if (user == null) throw Exception('User must be authenticated to update an event.');

      final firestore = ref.read(firestoreProvider);

      // Get the existing event to ensure it exists and to check permissions if needed
      final docRef = firestore.collection('events').doc(event.id);
      final snapshot = await docRef.get();
      if (!snapshot.exists) throw Exception('Event does not exist.');

      // Optionally, check if the user is the creator of the event
      final existingEvent = Event.fromJson(snapshot.data()!);
      if (existingEvent.createdBy != user.uid) {
        throw Exception('User does not have permission to update this event.');
      }

      await firestore.collection('events').doc(event.id).update(event.toJson());
    });
  }

  Future<void> cancelEvent(String eventId) async {
    // This method can be implemented to set a 'cancelled' flag on the event
    // instead of deleting it, depending on your application's requirements.
  }

  /// Deletes an event by ID.
  Future<void> deleteEvent(String eventId) async {
    if (eventId.isEmpty) throw ArgumentError('Event ID cannot be empty for deletion.');

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await ref.read(authProvider.future);
      if (user == null) throw Exception('User must be authenticated to delete an event.');

      final firestore = ref.read(firestoreProvider);

      // Get the existing event to ensure it exists and to check permissions if needed
      final docRef = firestore.collection('events').doc(eventId);
      final snapshot = await docRef.get();
      if (!snapshot.exists) throw Exception('Event does not exist.');

      // Optionally, check if the user is the creator of the event
      final existingEvent = Event.fromJson(snapshot.data()!);
      if (existingEvent.createdBy != user.uid) {
        throw Exception('User does not have permission to delete this event.');
      }

      await firestore.collection('events').doc(eventId).delete();
    });
  }
}

/// 4. Global Notifier Provider
final eventNotifier = AsyncNotifierProvider<EventAsyncNotifier, void>(() {
  return EventAsyncNotifier();
});