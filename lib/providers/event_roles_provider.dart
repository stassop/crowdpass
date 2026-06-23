import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/models/event.dart';
import 'package:crowdpass/models/user_profile.dart';

import 'package:crowdpass/providers/auth_provider.dart';
import 'package:crowdpass/providers/event_provider.dart';
import 'package:crowdpass/providers/user_profile_provider.dart';
import 'package:crowdpass/providers/firestore_provider.dart';

final userRoleProvider =
    StreamProvider.family<EventRole?, ({String eventId, String userId})>(
  (ref, params) async* {
    final firestore = ref.read(firestoreProvider);
    if (params.userId.isEmpty) {
      yield null;
      return;
    }

    for (final role in EventRole.values) {
      final snapshot = await firestore
          .collection('events')
          .doc(params.eventId)
          .collection(role.collectionName)
          .where('userId', isEqualTo: params.userId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        yield role;
        return;
      }
    }

    yield null;
  },
);

class EventRolesState {
  final Event? event;
  final Map<EventRole, List<UserProfile>> usersByRole;
  final Map<EventRole, bool> isLoadingByRole;
  final Map<EventRole, bool> hasMoreByRole;
  final Map<EventRole, DocumentSnapshot?> lastDocByRole;
  final Object? error;

  const EventRolesState({
    this.event,
    this.usersByRole = const {},
    this.isLoadingByRole = const {},
    this.hasMoreByRole = const {},
    this.lastDocByRole = const {}, 
    this.error,
  });

  List<UserProfile> usersForRole(EventRole role) => usersByRole[role] ?? const [];
  bool isLoadingRole(EventRole role) => isLoadingByRole[role] ?? false;
  bool hasMoreForRole(EventRole role) => hasMoreByRole[role] ?? true;

  EventRolesState copyWith({
    Event? event,
    Map<EventRole, List<UserProfile>>? usersByRole,
    Map<EventRole, bool>? isLoadingByRole,
    Map<EventRole, bool>? hasMoreByRole,
    Map<EventRole, DocumentSnapshot?>? lastDocByRole,
    Object? error,
  }) {
    return EventRolesState(
      event: event ?? this.event,
      usersByRole: usersByRole ?? this.usersByRole,
      isLoadingByRole: isLoadingByRole ?? this.isLoadingByRole,
      hasMoreByRole: hasMoreByRole ?? this.hasMoreByRole,
      lastDocByRole: lastDocByRole ?? this.lastDocByRole,
      error: error,
    );
  }
}

class EventRolesNotifier extends Notifier<EventRolesState> {
  EventRolesNotifier(this.eventId);

  static const int pageSize = 30;

  final String eventId;

  FirebaseFirestore get _firestore => ref.read(firestoreProvider);

  @override
  EventRolesState build() {
    Future.microtask(refresh);
    return EventRolesState(
      isLoadingByRole: { for (final role in EventRole.values) role: false },
      hasMoreByRole: { for (final role in EventRole.values) role: true },
      lastDocByRole: { for (final role in EventRole.values) role: null }, // <-- Initialize
    );
  }

  Future<void> refresh() async {
    state = state.copyWith(
      usersByRole: { for (final role in EventRole.values) role: const [] },
      isLoadingByRole: { for (final role in EventRole.values) role: true },
      hasMoreByRole: { for (final role in EventRole.values) role: true },
      lastDocByRole: { for (final role in EventRole.values) role: null }, 
      error: null,
    );

    try {
      final user = await ref.read(authProvider.future);
      if (user == null) {
        state = state.copyWith(
          isLoadingByRole: { for (final role in EventRole.values) role: false },
          hasMoreByRole: { for (final role in EventRole.values) role: false },
          error: 'User not authenticated',
        );
        return;
      }

      final event = await ref.read(eventProvider(eventId).future);
      if (event == null) {
        state = state.copyWith(
          event: null,
          isLoadingByRole: { for (final role in EventRole.values) role: false },
          hasMoreByRole: { for (final role in EventRole.values) role: false },
          error: 'Event not found'
        );
        return;
      }
      
      final userRole = await ref.read(
        userRoleProvider((eventId: eventId, userId: user.uid)).future,
      );
      if (userRole == null) {
        state = state.copyWith(
          event: event,
          isLoadingByRole: { for (final role in EventRole.values) role: false },
          hasMoreByRole: { for (final role in EventRole.values) role: false },
          error: 'User does not have a role in this event',
        );
        return;
      }

      state = state.copyWith(
        event: event,
        error: null,
      );

      await Future.wait([
        for (final role in EventRole.values) loadMore(role, replace: true),
      ]);
    } catch (error, stackTrace) {
      debugPrint('EventRolesNotifier error: $error\n$stackTrace');
      state = state.copyWith(
        isLoadingByRole: { for (final role in EventRole.values) role: false },
        hasMoreByRole: { for (final role in EventRole.values) role: false },
        error: error,
      );
    }
  }

  Future<void> loadMore(EventRole role, {bool replace = false}) async {
    if (!replace && (state.isLoadingRole(role) || !state.hasMoreForRole(role))) {
      return;
    }

    final nextLoadingByRole = {...state.isLoadingByRole, role: true};
    if (!replace) {
      state = state.copyWith(isLoadingByRole: nextLoadingByRole, error: null);
    }

    try {
      final event = state.event;
      if (event == null) {
        state = state.copyWith(isLoadingByRole: {...state.isLoadingByRole, role: false});
        return;
      }

      // 1. Build the query dynamically using the cursor map
      var query = _firestore
          .collection('events')
          .doc(event.id)
          .collection(role.collectionName)
          .limit(pageSize);

      // If we're appending data and have a saved cursor position, use it!
      final lastDoc = state.lastDocByRole[role];
      if (!replace && lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }

      final snapshot = await query.get();
      
      if (snapshot.docs.isEmpty) {
        state = state.copyWith(
          hasMoreByRole: {...state.hasMoreByRole, role: false},
          isLoadingByRole: {...state.isLoadingByRole, role: false},
        );
        return;
      }

      // Doc IDs are same as user IDs
      final userIds = snapshot.docs.map((doc) => doc.id).toList();

      if (userIds.isEmpty) {
        state = state.copyWith(isLoadingByRole: {...state.isLoadingByRole, role: false});
        return;
      }

      final fetchedProfiles = await _fetchProfilesInChunks(userIds);

      fetchedProfiles.sort(
        (a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );

      final existingUsers = replace ? <UserProfile>[] : state.usersForRole(role);

      // 2. Commit the updates alongside the new trailing document cursor
      state = state.copyWith(
        usersByRole: {
          ...state.usersByRole,
          role: replace ? fetchedProfiles : [...existingUsers, ...fetchedProfiles],
        },
        lastDocByRole: {
          ...state.lastDocByRole,
          role: snapshot.docs.last, // <-- Save the new boundary snapshot here
        },
        hasMoreByRole: {
          ...state.hasMoreByRole, 
          role: snapshot.docs.length == pageSize,
        },
        isLoadingByRole: {...state.isLoadingByRole, role: false},
        error: null,
      );
    } catch (error, stackTrace) {
      debugPrint('loadMore($role) error: $error\n$stackTrace');
      state = state.copyWith(
        isLoadingByRole: {...state.isLoadingByRole, role: false},
        hasMoreByRole: {...state.hasMoreByRole, role: false},
        error: error,
      );
    }
  }

  // Efficient batching helper method
  Future<List<UserProfile>> _fetchProfilesInChunks(List<String> userIds) async {
    final List<UserProfile> profiles = [];
    const int chunkSize = 30; // Firestore whereIn limit

    final List<List<String>> chunks = [];
    for (var i = 0; i < userIds.length; i += chunkSize) {
      chunks.add(userIds.sublist(i, i + chunkSize > userIds.length ? userIds.length : i + chunkSize));
    }

    // Execute all chunk requests concurrently via Future.wait
    final futures = chunks.map((chunk) async {
      final querySnapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      return querySnapshot.docs
          .map((doc) => UserProfile.fromJson({...doc.data(), 'uid': doc.id}))
          .toList();
    });

    final results = await Future.wait(futures);
    for (final list in results) {
      profiles.addAll(list);
    }

    return profiles;
  }

  Future<void> addUserToRole({
    required String userId,
    required EventRole role,
  }) async {
    try {
      final event = state.event;
      if (event == null) {
        throw Exception('Event not found.');
      }

      final userRole = await ref.read(
        userRoleProvider((eventId: eventId, userId: userId)).future,
      );

      if (userRole == EventRole.owner) {
        throw Exception('Cannot change event owner.');
      }

      final currentUserRole = await ref.read(
        userRoleProvider((
          eventId: eventId,
          userId: ref.read(authProvider).value?.uid ?? '',
        )).future, // Current authenticated user's role
      );

      if (currentUserRole != EventRole.owner && currentUserRole != EventRole.admin) {
        throw Exception('You do not have permission to manage roles.');
      }

      final eventRef = _firestore.collection('events').doc(eventId);
      final batch = _firestore.batch();

      for (final existingRole in EventRole.values) {
        final snapshot = await eventRef
            .collection(existingRole.collectionName)
            .where('userId', isEqualTo: userId)
            .get();

        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
      }

      final docRef = eventRef.collection(role.collectionName).doc(userId);
      batch.set(docRef, {
        'userId': userId,
        'eventId': eventId,
        'role': role.name,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      await Future.wait([
        for (final existingRole in EventRole.values)
          loadMore(existingRole, replace: true),
      ]);
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
      final event = state.event;
      if (event == null) {
        throw Exception('Event not found.');
      }

      final userRole = await ref.read(
        userRoleProvider((eventId: eventId, userId: userId)).future,
      );

      if (userRole == EventRole.owner) {
        throw Exception('Cannot change event owner.');
      }

      final currentUserRole = await ref.read(
        userRoleProvider((
          eventId: eventId,
          userId: ref.read(authProvider).value?.uid ?? '',
        )).future, // Current authenticated user's role
      );

      if (currentUserRole != EventRole.owner && currentUserRole != EventRole.admin) {
        throw Exception('You do not have permission to manage roles.');
      }

      final snapshot = await _firestore
          .collection('events')
          .doc(eventId)
          .collection(role.collectionName)
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }

      state = state.copyWith(
        usersByRole: {
          ...state.usersByRole,
          role: state.usersForRole(role)
              .where((user) => user.uid != userId)
              .toList(),
        },
        error: null,
      );

      if (state.usersForRole(role).length < pageSize && state.hasMoreForRole(role)) {
        await loadMore(role);
      }
    } catch (error, stackTrace) {
      debugPrint('removeUserFromRole error: $error\n$stackTrace');
      state = state.copyWith(error: error);
    }
  }
}

final eventRolesProvider =
    NotifierProvider.family<EventRolesNotifier, EventRolesState, String>(
  (eventId) => EventRolesNotifier(eventId),
);