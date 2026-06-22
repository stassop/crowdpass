import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/models/event.dart';
import 'package:crowdpass/models/user_profile.dart';

import 'package:crowdpass/providers/auth_provider.dart';
import 'package:crowdpass/providers/event_provider.dart';
import 'package:crowdpass/providers/firestore_provider.dart';
import 'package:crowdpass/providers/user_profile_provider.dart';

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

  List<UserProfile> usersForRole(EventRole role) => usersByRole[role] ?? const [];

  bool isLoadingRole(EventRole role) => isLoadingByRole[role] ?? false;

  bool hasMoreForRole(EventRole role) => hasMoreByRole[role] ?? true;

  EventRolesState copyWith({
    Event? event,
    Map<EventRole, List<UserProfile>>? usersByRole,
    Map<EventRole, bool>? isLoadingByRole,
    Map<EventRole, bool>? hasMoreByRole,
    Object? error,
    bool clearError = false,
  }) {
    return EventRolesState(
      event: event ?? this.event,
      usersByRole: usersByRole ?? this.usersByRole,
      isLoadingByRole: isLoadingByRole ?? this.isLoadingByRole,
      hasMoreByRole: hasMoreByRole ?? this.hasMoreByRole,
      error: clearError ? null : (error ?? this.error),
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
    return const EventRolesState();
  }

  Future<void> refresh() async {
    state = EventRolesState(
      event: state.event,
      usersByRole: {},
      isLoadingByRole: {
        for (final role in EventRole.values) role: false,
      },
      hasMoreByRole: {
        for (final role in EventRole.values) role: true,
      },
      error: null,
    );

    try {
      final user = await ref.read(authProvider.future);
      if (user == null) {
        state = state.copyWith(error: 'User not authenticated');
        return;
      }

      final event = await ref.read(eventProvider(eventId).future);
      if (event == null) {
        state = state.copyWith(event: null, error: 'Event not found');
        return;
      }

      final currentUserRole =
          await ref.read(userRoleProvider((eventId: eventId, userId: user.uid)).future);
      if (currentUserRole == null) {
        state = state.copyWith(
          event: event,
          error: 'You do not have permission to view event roles',
        );
        return;
      }

      state = state.copyWith(event: event, clearError: true);
    } catch (error, stackTrace) {
      debugPrint('EventRolesNotifier refresh error: $error\n$stackTrace');
      state = state.copyWith(error: error);
    }
  }

  Future<void> loadMore(EventRole role, {bool replace = false}) async {
    if (!replace && (state.isLoadingRole(role) || !state.hasMoreForRole(role))) {
      return;
    }

    state = state.copyWith(
      isLoadingByRole: {...state.isLoadingByRole, role: true},
      clearError: true,
    );

    try {
      final event = state.event;
      if (event == null) {
        state = state.copyWith(
          isLoadingByRole: {...state.isLoadingByRole, role: false},
          hasMoreByRole: {...state.hasMoreByRole, role: false},
        );
        return;
      }

      final snapshot = await _firestore
          .collection('events')
          .doc(event.id)
          .collection(role.collectionName)
          .get();

      final fetchedUsers = <UserProfile>[];
      final seenUserIds = <String>{};

      for (final doc in snapshot.docs) {
        final userId = doc.data()['userId'] as String?;
        if (userId == null || userId.isEmpty || !seenUserIds.add(userId)) {
          continue;
        }

        final userProfile = await ref.read(userProfileProvider(userId).future);
        if (userProfile != null) {
          fetchedUsers.add(userProfile);
        }
      }

      final existingUsers = replace ? <UserProfile>[] : state.usersForRole(role);
      final startIndex = replace ? 0 : existingUsers.length;

      if (startIndex >= fetchedUsers.length) {
        state = state.copyWith(
          usersByRole: {...state.usersByRole, role: existingUsers},
          hasMoreByRole: {...state.hasMoreByRole, role: false},
          isLoadingByRole: {...state.isLoadingByRole, role: false},
        );
        return;
      }

      final endIndex = (startIndex + pageSize).clamp(0, fetchedUsers.length);
      final pageUsers = fetchedUsers.sublist(startIndex, endIndex);

      state = state.copyWith(
        usersByRole: {
          ...state.usersByRole,
          role: [...existingUsers, ...pageUsers],
        },
        hasMoreByRole: {
          ...state.hasMoreByRole,
          role: endIndex < fetchedUsers.length,
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

  Future<void> addUserToRole({
    required String userId,
    required EventRole role,
  }) async {
    try {
      final event = state.event;
      if (event == null) {
        throw Exception('Event not found.');
      }

      final currentUserRole =
          await ref.read(userRoleProvider((eventId: eventId, userId: null)).future);

      if (currentUserRole != EventRole.owner && currentUserRole != EventRole.admin) {
        throw Exception('You do not have permission to manage roles.');
      }

      final existingRole =
          await ref.read(userRoleProvider((eventId: eventId, userId: userId)).future);

      if (existingRole == EventRole.owner) {
        throw Exception('Cannot change event owner.');
      }

      final eventRef = _firestore.collection('events').doc(eventId);
      final batch = _firestore.batch();

      for (final existing in EventRole.values) {
        final snapshot = await eventRef
            .collection(existing.collectionName)
            .where('userId', isEqualTo: userId)
            .get();

        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
      }

      batch.set(eventRef.collection(role.collectionName).doc(userId), {
        'userId': userId,
        'eventId': eventId,
        'role': role.name,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      await loadMore(role, replace: true);
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

      final currentUserRole =
          await ref.read(userRoleProvider((eventId: eventId, userId: null)).future);

      if (currentUserRole != EventRole.owner && currentUserRole != EventRole.admin) {
        throw Exception('You do not have permission to manage roles.');
      }

      final existingRole =
          await ref.read(userRoleProvider((eventId: eventId, userId: userId)).future);

      if (existingRole == EventRole.owner) {
        throw Exception('Cannot change event owner.');
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

      final updatedUsers = state.usersForRole(role)
          .where((user) => user.uid != userId)
          .toList();

      state = state.copyWith(
        usersByRole: {...state.usersByRole, role: updatedUsers},
        clearError: true,
      );
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