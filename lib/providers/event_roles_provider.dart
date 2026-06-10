import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/models/event.dart';
import 'package:crowdpass/providers/auth_provider.dart';

class EventRolesState {
  final Event? event;
  final EventRole? currentUserRole;
  final Map<EventRole, List<String>> roleToUserIds;
  final bool isOwner;
  final bool isLoading;
  final Object? error;

  const EventRolesState({
    this.event,
    this.currentUserRole,
    this.roleToUserIds = const {},
    this.isOwner = false,
    this.isLoading = false,
    this.error,
  });

  EventRolesState copyWith({
    Event? event,
    EventRole? currentUserRole,
    Map<EventRole, List<String>>? roleToUserIds,
    bool? isOwner,
    bool? isLoading,
    Object? error,
  }) {
    return EventRolesState(
      event: event ?? this.event,
      currentUserRole: currentUserRole ?? this.currentUserRole,
      roleToUserIds: roleToUserIds ?? this.roleToUserIds,
      isOwner: isOwner ?? this.isOwner,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class EventRolesNotifier extends Notifier<EventRolesState> {
  EventRolesNotifier(this.eventId);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String eventId;

  @override
  EventRolesState build() {
    Future.microtask(refresh);
    return const EventRolesState();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final user = await ref.read(authProvider.future);

      if (user == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'User not authenticated',
        );
        return;
      }

      final eventDoc = await _firestore.collection('events').doc(eventId).get();

      if (!eventDoc.exists || eventDoc.data() == null) {
        state = state.copyWith(
          event: null,
          currentUserRole: null,
          roleToUserIds: const {},
          isOwner: false,
          isLoading: false,
          error: null,
        );
        return;
      }

      final eventData = Map<String, dynamic>.from(eventDoc.data()!);
      eventData['id'] = eventDoc.id;
      final event = Event.fromJson(eventData);

      final isOwner = event.createdBy == user.uid;
      final currentUserRole = await _getUserRoleForEvent(
        eventId: event.id,
        userId: user.uid,
      );

      Map<EventRole, List<String>> roleToUserIds = const {};
      if (isOwner) {
        roleToUserIds = await _getAllRolesForEvent(event.id);
      }

      state = state.copyWith(
        event: event,
        currentUserRole: currentUserRole,
        roleToUserIds: roleToUserIds,
        isOwner: isOwner,
        isLoading: false,
        error: null,
      );
    } catch (error, stackTrace) {
      debugPrint('EventRolesNotifier error: $error\n$stackTrace');
      state = state.copyWith(
        isLoading: false,
        error: error,
      );
    }
  }

  Future<EventRole?> _getUserRoleForEvent({
    required String eventId,
    required String userId,
  }) async {
    for (final role in EventRole.values) {
      final snapshot = await _firestore
          .collection('events')
          .doc(eventId)
          .collection(role.collectionName)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) return role;
    }

    return null;
  }

  Future<Map<EventRole, List<String>>> _getAllRolesForEvent(String eventId) async {
    final result = <EventRole, List<String>>{};

    for (final role in EventRole.values) {
      final snapshot = await _firestore
          .collection('events')
          .doc(eventId)
          .collection(role.collectionName)
          .get();

      result[role] = snapshot.docs
          .map((doc) => doc.data()['userId'] as String?)
          .whereType<String>()
          .toList();
    }

    return result;
  }

  Future<void> addUserToRole({
    required String userId,
    required EventRole role,
  }) async {
    try {
      await _assertOwner();

      final eventRef = _firestore.collection('events').doc(eventId);
      final batch = _firestore.batch();

      for (final existingRole in EventRole.values) {
        final existingDocs = await eventRef
            .collection(existingRole.collectionName)
            .where('userId', isEqualTo: userId)
            .get();

        for (final doc in existingDocs.docs) {
          batch.delete(doc.reference);
        }
      }

      final newDoc = eventRef.collection(role.collectionName).doc();
      batch.set(newDoc, {'userId': userId});

      await batch.commit();
      await refresh();
    } catch (error, stackTrace) {
      debugPrint('addUserToRole error: $error\n$stackTrace');
      state = state.copyWith(error: error);
    }
  }

  Future<void> removeUserFromRole({
    required String userId,
    required EventRole role,
  }) async {
    try {
      await _assertOwner();

      final snapshot = await _firestore
          .collection('events')
          .doc(eventId)
          .collection(role.collectionName)
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }

      await refresh();
    } catch (error, stackTrace) {
      debugPrint('removeUserFromRole error: $error\n$stackTrace');
      state = state.copyWith(error: error);
    }
  }

  Future<void> _assertOwner() async {
    final user = await ref.read(authProvider.future);
    if (user == null) {
      throw Exception('User not authenticated.');
    }

    final event = state.event;
    if (event == null) {
      throw Exception('Event not found.');
    }

    if (event.createdBy != user.uid) {
      throw Exception('Only the event owner can manage roles.');
    }
  }
}

final eventRolesProvider =
    NotifierProvider.family<EventRolesNotifier, EventRolesState, String>(
  EventRolesNotifier.new,
);