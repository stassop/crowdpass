import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/services/image_file_service.dart';

import 'package:crowdpass/providers/auth_provider.dart';
import 'package:crowdpass/providers/company_provider.dart';
import 'package:crowdpass/providers/firestore_provider.dart';

import 'package:crowdpass/models/event.dart';
import 'package:crowdpass/models/money.dart';
import 'package:crowdpass/models/location.dart';
import 'package:crowdpass/models/time_range.dart';

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
  Future<String?> createEvent({
    required DateTimeRange dates,
    required String description,
    required Location location,
    required String title,
    required EventType type,
    required TimeRange times,
    bool doorTicketsAvailable = false, // No longer required
    String? imagePath,
    bool? isEpilepsyFriendly,
    bool isFree = false, // No longer required
    bool? isFamilyFriendly,
    bool? isHearingAidCompatible,
    bool isOutdoor = false, // No longer required
    bool? isLowSensoryFriendly,
    bool? isPetFriendly,
    bool isWheelchairAccessible = false, // No longer required
    int? maxTicketsAvailable,
    Money? ticketPrice, // No longer required
    DateTimeRange? ticketSalesDates,
    int? venueCapacity,
  }) async {
    state = const AsyncLoading();
    try {
      final user = ref.read(authProvider).value;
      if (user == null) {
        throw Exception('User must be authenticated to create an event.');
      }

      final company = ref.read(companyProvider(null)).value;
      if (company == null) {
        throw Exception('Only company owners can create events. Create a company first.');
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
      final eventId = docRef.id; // Get the auto-generated ID before creating the event

      final event = Event(
        companyId: company.id,
        createdBy: user.uid,
        dates: dates,
        doorTicketsAvailable: doorTicketsAvailable,
        description: description,
        id: eventId,
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
        ticketPrice: ticketPrice, 
        type: type,
        ticketSalesDates: ticketSalesDates,
        title: title,
        times: times,
      );
      await docRef.set(event.toJson());
      
      state = const AsyncData(null);

      return eventId; // Return the new event ID for navigation or further actions
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
      final user = ref.read(authProvider).value;
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
          
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
  // Removed stray lines from previous broken patch

  Future<void> cancelEvent(String eventId) async {
    if (eventId.isEmpty) {
      throw ArgumentError('Event ID cannot be empty for deletion.');
    }

    state = const AsyncLoading();
    try {
      final user = ref.read(authProvider).value;
      if (user == null) {
        throw Exception('User must be authenticated to delete an event.');
      }

      final firestore = ref.read(firestoreProvider);

      // Get the existing event to ensure it exists and to check permissions if needed
      final docRef = firestore.collection('events').doc(eventId);
      final snapshot = await docRef.get();
      if (!snapshot.exists) throw Exception('Event does not exist.');

      // Optionally, check if the user is the creator of the event
      // This logic is commented out until the 'createdBy' field is reliably available

      await docRef.delete();
      
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final eventNotifier = AsyncNotifierProvider<EventAsyncNotifier, void>(() {
  return EventAsyncNotifier();
});