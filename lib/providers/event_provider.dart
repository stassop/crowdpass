import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:crowdpass/services/image_file_service.dart';
import 'package:crowdpass/providers/auth_provider.dart';
import 'package:crowdpass/providers/company_provider.dart';
import 'package:crowdpass/providers/firestore_provider.dart';

import 'package:crowdpass/models/event.dart';
import 'package:crowdpass/models/money.dart';
import 'package:crowdpass/models/location.dart';
import 'package:crowdpass/models/time_range.dart';

/// Watches a specific event by ID.
final eventProvider = StreamProvider.family<Event?, String?>((ref, eventId) {
  if (eventId == null || eventId.isEmpty) return Stream.value(null);

  final firestore = ref.watch(firestoreProvider);

  return firestore.collection('events').doc(eventId).snapshots().map((snapshot) {
    final data = snapshot.data();
    if (data == null || !snapshot.exists) return null;
    
    data['id'] = snapshot.id;
    return Event.fromJson(data);
  });
});

/// Handles side effects (Create, Update, Cancel, Delete).
class EventAsyncNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Creates an event and links it to the company atomically.
  Future<String?> createEvent({
    required DateTimeRange dates,
    required String description,
    required Location location,
    required String title,
    required EventType type,
    required TimeRange times,
    bool doorTicketsAvailable = false,
    String? imagePath,
    bool? isEpilepsyFriendly,
    bool isFree = false,
    bool? isFamilyFriendly,
    bool? isHearingAidCompatible,
    bool isOutdoor = false,
    bool? isLowSensoryFriendly,
    bool? isPetFriendly,
    bool isWheelchairAccessible = false,
    int? maxTicketsAvailable,
    Money? ticketPrice,
    DateTimeRange? ticketSalesDates,
    int? venueCapacity,
  }) async {
    state = const AsyncLoading();
    try {
      // Resolve futures to ensure data is present before proceeding
      final user = await ref.read(authProvider.future);
      final company = await ref.read(companyProvider(null).future);

      if (user == null) throw Exception('Authentication required.');
      if (company == null) throw Exception('Company profile required.');

      final firestore = ref.read(firestoreProvider);
      final batch = firestore.batch();
      
      String? imageURL;
      if (imagePath != null && imagePath.isNotEmpty) {
        imageURL = await ImageFileService.uploadImage(
          imagePath,
          'events/${company.id}/images',
        );
      }

      final docRef = firestore.collection('events').doc();
      final eventId = docRef.id;

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

      // Atomic write: Event entry + Company reference
      batch.set(docRef, event.toJson());
      batch.set(
        firestore
            .collection('companies')
            .doc(company.id)
            .collection('events')
            .doc(eventId),
        {'eventId': eventId, 'createdAt': FieldValue.serverTimestamp()},
      );

      await batch.commit();
      
      state = const AsyncData(null);
      return eventId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateEvent({
    required Event updatedEvent,
    String? imagePath,
  }) async {
    state = const AsyncLoading();
    try {
      final user = await ref.read(authProvider.future);
      if (user == null) throw Exception('Authentication required.');

      final currentEvent = await ref.read(eventProvider(updatedEvent.id).future);
      if (currentEvent == null) throw Exception('Event does not exist.');
      if (currentEvent.createdBy != user.uid) {
        throw Exception('Unauthorized update attempt.');
      }

      String? imageURL = currentEvent.imageURL;
      if (imagePath != null && imagePath.isNotEmpty) {
        imageURL = await ImageFileService.uploadImage(
          imagePath,
          'events/${currentEvent.companyId}/images',
        );
      }

      final eventToUpdate = updatedEvent.copyWith(imageURL: imageURL);
      final firestore = ref.read(firestoreProvider);

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

  Future<void> cancelEvent(String eventId) async {
    if (eventId.isEmpty) throw ArgumentError('Invalid Event ID.');

    state = const AsyncLoading();
    try {
      final user = await ref.read(authProvider.future);
      final currentEvent = await ref.read(eventProvider(eventId).future);

      if (user == null || currentEvent == null) throw Exception('Data mismatch.');
      if (currentEvent.createdBy != user.uid) throw Exception('Unauthorized.');

      final firestore = ref.read(firestoreProvider);
      await firestore
          .collection('events')
          .doc(eventId)
          .update({'isCanceled': true});

      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteEvent(String eventId) async {
    if (eventId.isEmpty) throw ArgumentError('Invalid Event ID.');

    state = const AsyncLoading();
    try {
      final user = await ref.read(authProvider.future);
      final currentEvent = await ref.read(eventProvider(eventId).future);

      if (user == null || currentEvent == null) throw Exception('Data mismatch.');
      if (currentEvent.createdBy != user.uid) throw Exception('Unauthorized.');

      if (currentEvent.dates.start.isBefore(DateTime.now())) {
        throw Exception('Cannot delete events that have already started.');
      }

      final firestore = ref.read(firestoreProvider);
      final batch = firestore.batch();

      // Delete from main collection
      batch.delete(firestore.collection('events').doc(eventId));
      
      // Delete reference from company subcollection
      batch.delete(
        firestore
            .collection('companies')
            .doc(currentEvent.companyId)
            .collection('events')
            .doc(eventId),
      );

      await batch.commit();
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