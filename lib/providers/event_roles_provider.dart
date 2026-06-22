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
    StreamProvider.family<EventRole?, ({String eventId, String? userId})>(
  (ref, params) async* {
    final firestore = ref.read(firestoreProvider);
    final resolvedUserId =
        params.userId ?? (await ref.read(authProvider.future))?.uid;

    if (resolvedUserId == null || resolvedUserId.isEmpty) {
      yield null;
      return;
    }

    for (final role in EventRole.values) {
      final snapshot = await firestore
          .collection('events')
          .doc(params.eventId)
          .collection(role.collectionName)
          .where('userId', isEqualTo: resolvedUserId)
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
  final Object? error;

  const EventRolesState({
    this.event,
    this.usersByRole = const {},
    this.isLoadingByRole = const {},
    this.hasMoreByRole = const {},
    this.error,
  });

  List<UserProfile> usersForRole(EventRole role) =>
      usersByRole[role] ?? const [];

  bool isLoadingRole(EventRole role) => isLoadingByRole[role] ?? false;

  bool hasMoreForRole(EventRole role) => hasMoreByRole[role] ?? true;

  EventRolesState copyWith({
    Event? event,
    Map<EventRole, List<UserProfile>>? usersByRole,
    Map<EventRole, bool>? isLoadingByRole,
    Map<EventRole, bool>? hasMoreByRole,
    Object? error,
  }) {
    return EventRolesState(
      event: event ?? this.event,
      usersByRole: usersByRole ?? this.usersByRole,
      isLoadingByRole: isLoadingByRole ?? this.isLoadingByRole,
      hasMoreByRole: hasMoreByRole ?? this.hasMoreByRole,
      error: error,
    );
  }
}

class EventRolesNotifier extends Notifier<EventRolesState> {
  EventRolesNotifier(this.eventId);

  static const int pageSize = 20;

  final String eventId;

  FirebaseFirestore get _firestore => ref.read(firestoreProvider);

  @override
  EventRolesState build() {
    Future.microtask(refresh);
    return EventRolesState(
      isLoadingByRole: {
        for (final role in EventRole.values) role: false,
      },
      hasMoreByRole: {
        for (final role in EventRole.values) role: true,
      },
    );
  }

  Future<void> refresh() async {
    state = state.copyWith(
      usersByRole: {
        for (final role in EventRole.values) role: const [],
      },
      isLoadingByRole: {
        for (final role in EventRole.values) role: true,
      },
      hasMoreByRole: {
        for (final role in EventRole.values) role: true,
      },
      error: null,
    );

    try {
      final user = await ref.read(authProvider.future);
      if (user == null) {
        state = state.copyWith(
          isLoadingByRole: {
            for (final role in EventRole.values) role: false,
          },
          hasMoreByRole: {
            for (final role in EventRole.values) role: false,
          },
          error: 'User not authenticated',
        );
        return;
      }

      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      if (!eventDoc.exists || eventDoc.data() == null) {
        state = state.copyWith(
          event: null,
          isLoadingByRole: {
            for (final role in EventRole.values) role: false,
          },
          hasMoreByRole: {
            for (final role in EventRole.values) role: false,
          },
          error: null,
        );
        return;
      }

      final eventData = Map<String, dynamic>.from(eventDoc.data()!);
      eventData['id'] = eventDoc.id;
      final event = Event.fromJson(eventData);

      final isOwner = event.createdBy == user.uid;

      if (!isOwner) {
        state = state.copyWith(
          event: event,
          isLoadingByRole: {
            for (final role in EventRole.values) role: false,
          },
          hasMoreByRole: {
            for (final role in EventRole.values) role: false,
          },
          error: null,
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
        isLoadingByRole: {
          for (final role in EventRole.values) role: false,
        },
        hasMoreByRole: {
          for (final role in EventRole.values) role: false,
        },
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
        state = state.copyWith(
          isLoadingByRole: {...state.isLoadingByRole, role: false},
        );
        return;
      }

      final snapshot = await _firestore
          .collection('events')
          .doc(event.id)
          .collection(role.collectionName)
          .get();

      final fetchedUsers = <UserProfile>[];
      for (final doc in snapshot.docs) {
        final userId = doc.data()['userId'] as String?;
        if (userId == null || userId.isEmpty) continue;

        final userProfile = await _getUserProfile(userId);
        if (userProfile == null) continue;

        fetchedUsers.add(userProfile);
      }

      fetchedUsers.sort(
        (firstUser, secondUser) => firstUser.displayName
            .toLowerCase()
            .compareTo(secondUser.displayName.toLowerCase()),
      );

      final existingUsers = replace ? <UserProfile>[] : state.usersForRole(role);
      final startIndex = replace ? 0 : existingUsers.length;

      if (startIndex >= fetchedUsers.length) {
        state = state.copyWith(
          hasMoreByRole: {...state.hasMoreByRole, role: false},
          isLoadingByRole: {...state.isLoadingByRole, role: false},
          error: null,
        );
        return;
      }

      final endIndex = (startIndex + pageSize).clamp(0, fetchedUsers.length);
      final pageUsers = fetchedUsers.sublist(startIndex, endIndex);

      state = state.copyWith(
        usersByRole: {
          ...state.usersByRole,
          role: replace ? pageUsers : [...existingUsers, ...pageUsers],
        },
        hasMoreByRole: {
          ...state.hasMoreByRole,
          role: endIndex < fetchedUsers.length
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

  Future<UserProfile?> _getUserProfile(String userId) async {
    try {
      final snapshot = await _firestore.collection('users').doc(userId).get();
      if (!snapshot.exists || snapshot.data() == null) return null;

      return UserProfile.fromJson({
        ...snapshot.data()!,
        'uid': snapshot.id,
      });
    } catch (error, stackTrace) {
      debugPrint('Error fetching user profile: $error\n$stackTrace');
      return null;
    }
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
        userRoleProvider((eventId: eventId, userId: null)).future, // Current authenticated user's role
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
        userRoleProvider((eventId: eventId, userId: null)).future, // Current authenticated user's role
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