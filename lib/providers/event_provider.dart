import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/services/image_file_service.dart';

import 'package:crowdpass/providers/auth_provider.dart';
import 'package:crowdpass/providers/company_provider.dart';
import 'package:crowdpass/providers/firestore_provider.dart';

import 'package:crowdpass/models/event.dart';
import 'package:crowdpass/models/location.dart';
import 'package:crowdpass/models/time_range.dart';

/// 2. Data Stream Provider
/// Watches a specific event by ID.
/// Using .family allows you to pass the eventId as a parameter.
final eventProvider = StreamProvider.family<Event?, String?>((ref, eventId) {
  if (eventId == null || eventId.isEmpty) return Stream.value(null);

  final firestore = ref.watch(firestoreProvider);

  return firestore.collection('events').doc(eventId).snapshots().map((
    snapshot,
  ) {
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
  Future<void> createEvent({
    required DateTimeRange dates,
    required bool isFree,
    required bool isOutdoor,
    required bool isWheelchairAccessible,
    required Location location,
    required String description,
    required String title,
    required EventType type,
    required TimeRange times,
    required DateTimeRange ticketSaleDates,
    bool? doorTicketsAvailable,
    bool? isEpilepsyFriendly,
    bool? isFamilyFriendly,
    bool? isHearingAidCompatible,
    bool? isLowSensoryFriendly,
    bool? isPetFriendly,
    int? maxTicketsAvailable,
    int? venueCapacity,
    String? imagePath,
  }) async {
    state = const AsyncLoading();
    try {
      state = await AsyncValue.guard(() async {
        final user = await ref.read(authProvider.future);
        if (user == null) {
          throw Exception('User must be authenticated to create an event.');
        }

        final company = await ref.read(companyProvider(null).future);
        if (company == null) {
          throw Exception('Only company owners can create events.');
        }

        String? imageURL;
        if (imagePath != null && imagePath.isNotEmpty) {
          imageURL = await ImageFileService.uploadImage(
            imagePath,
            'events/${company.id}/images',
          );
        }
        final firestore = ref.read(firestoreProvider);
        final docRef = firestore.collection('events').doc();

        final event = Event(
          companyId: company.id,
          createdBy: user.uid,
          dates: dates,
          doorTicketsAvailable: doorTicketsAvailable,
          description: description,
          id: docRef.id,
          imageURL: imageURL,
          isEpilepsyFriendly: isEpilepsyFriendly,
          isFamilyFriendly: isFamilyFriendly,
          isFree: isFree,
          isHearingAidCompatible: isHearingAidCompatible,
          isLowSensoryFriendly: isLowSensoryFriendly,
          isOutdoor: isOutdoor,
          isPetFriendly: isPetFriendly,
          isWheelchairAccessible: isWheelchairAccessible,
          location: location,
          maxTicketsAvailable: maxTicketsAvailable,
          type: type,
          ticketSaleDates: ticketSaleDates,
          title: title,
          times: times,
        );
        await docRef.set(event.toJson());
      });
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateEvent({
    required Event updatedEvent, // Accept an Event object
    String? imagePath,
  }) async {
    state = const AsyncLoading();
    try {
      state = await AsyncValue.guard(() async {
        final user = await ref.read(authProvider.future);
        if (user == null) {
          throw Exception('User must be authenticated to update an event.');
        }

        final firestore = ref.read(firestoreProvider);
        final docRef = firestore.collection('events').doc(updatedEvent.id);
        final snapshot = await docRef.get();
        if (!snapshot.exists) throw Exception('Event does not exist.');

        final existingEvent = Event.fromJson(snapshot.data()!);
        if (existingEvent.createdBy != user.uid) {
          throw Exception(
            'User does not have permission to update this event.',
          );
        }

        String? imageURL = existingEvent.imageURL;
        if (imagePath != null && imagePath.isNotEmpty) {
          imageURL = await ImageFileService.uploadImage(
            imagePath,
            'events/${existingEvent.companyId}/images',
          );
        }

        // Create a new Event object with the updated imageURL
        final eventToUpdate = updatedEvent.copyWith(imageURL: imageURL);

        await firestore
            .collection('events')
            .doc(updatedEvent.id)
            .update(eventToUpdate.toJson());
      });
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
  // Removed stray lines from previous broken patch

  Future<void> cancelEvent(String eventId) async {
    // This method can be implemented to set a 'cancelled' flag on the event
    // instead of deleting it, depending on your application's requirements.
  }

  /// Deletes an event by ID.
  Future<void> deleteEvent(String eventId) async {
    if (eventId.isEmpty)
      throw ArgumentError('Event ID cannot be empty for deletion.');

    state = const AsyncLoading();
    try {
      state = await AsyncValue.guard(() async {
        final user = await ref.read(authProvider.future);
        if (user == null)
          throw Exception('User must be authenticated to delete an event.');

        final firestore = ref.read(firestoreProvider);

        // Get the existing event to ensure it exists and to check permissions if needed
        final docRef = firestore.collection('events').doc(eventId);
        final snapshot = await docRef.get();
        if (!snapshot.exists) throw Exception('Event does not exist.');

        // Optionally, check if the user is the creator of the event
        // This logic is commented out until the 'createdBy' field is reliably available

        await docRef.delete();
      });
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final eventNotifier = AsyncNotifierProvider<EventAsyncNotifier, void>(() {
  return EventAsyncNotifier();
});
