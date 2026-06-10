import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/models/event.dart';
import 'package:crowdpass/models/user_profile.dart';
import 'package:crowdpass/providers/auth_provider.dart';
import 'package:crowdpass/providers/firestore_provider.dart';

class EventRolesFilters {
  final Set<EventRole> roles;

  const EventRolesFilters({
    this.roles = const {},
  });

  EventRolesFilters copyWith({
    Set<EventRole>? roles,
  }) {
    return EventRolesFilters(
      roles: roles ?? this.roles,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is EventRolesFilters && setEquals(other.roles, roles);
  }

  @override
  int get hashCode => Object.hashAll(roles);
}

class EventRolesState {
  final Event? event;
  final EventRole? currentUserRole;
  final List<UserProfile> users;
  final Map<String, EventRole> userToRole;
  final EventRolesFilters filters;
  final bool isOwner;
  final bool isLoading;
  final bool hasMore;
  final Object? error;

  const EventRolesState({
    this.event,
    this.currentUserRole,
    this.users = const [],
    this.userToRole = const {},
    this.filters = const EventRolesFilters(),
    this.isOwner = false,
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  EventRolesState copyWith({
    Event? event,
    EventRole? currentUserRole,
    List<UserProfile>? users,
    Map<String, EventRole>? userToRole,
    EventRolesFilters? filters,
    bool? isOwner,
    bool? isLoading,
    bool? hasMore,
    Object? error,
  }) {
    return EventRolesState(
      event: event ?? this.event,
      currentUserRole: currentUserRole ?? this.currentUserRole,
      users: users ?? this.users,
      userToRole: userToRole ?? this.userToRole,
      filters: filters ?? this.filters,
      isOwner: isOwner ?? this.isOwner,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
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
    return const EventRolesState();
  }

  void setFilters(EventRolesFilters newFilters) {
    if (state.filters == newFilters) return;
    state = state.copyWith(filters: newFilters);
    Future.microtask(refresh);
  }

  void toggleRoleFilter(EventRole role) {
    final updatedRoles = {...state.filters.roles};
    if (updatedRoles.contains(role)) {
      updatedRoles.remove(role);
    } else {
      updatedRoles.add(role);
    }
    setFilters(state.filters.copyWith(roles: updatedRoles));
  }

  void resetFilters() {
    setFilters(const EventRolesFilters());
  }

  Future<void> refresh() async {
    state = state.copyWith(
      users: const [],
      userToRole: const {},
      isLoading: true,
      hasMore: true,
      error: null,
    );

    await _loadMoreInternal(replace: true);
    state = state.copyWith(isLoading: false);
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true, error: null);
    await _loadMoreInternal(replace: false);
    state = state.copyWith(isLoading: false);
  }

  Future<void> _loadMoreInternal({required bool replace}) async {
    try {
      final user = await ref.read(authProvider.future);
      if (user == null) {
        state = state.copyWith(
          users: const [],
          userToRole: const {},
          hasMore: false,
          error: 'User not authenticated',
        );
        return;
      }

      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      if (!eventDoc.exists || eventDoc.data() == null) {
        state = state.copyWith(
          event: null,
          currentUserRole: null,
          users: const [],
          userToRole: const {},
          hasMore: false,
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

      if (!isOwner) {
        state = state.copyWith(
          event: event,
          currentUserRole: currentUserRole,
          users: const [],
          userToRole: const {},
          isOwner: false,
          hasMore: false,
          error: null,
        );
        return;
      }

      final selectedRoles = state.filters.roles.isEmpty
          ? EventRole.values.toSet()
          : state.filters.roles;

      final fetchedUsers = <UserProfile>[];
      final fetchedUserToRole = <String, EventRole>{};

      for (final role in EventRole.values) {
        if (!selectedRoles.contains(role)) continue;

        final snapshot = await _firestore
            .collection('events')
            .doc(event.id)
            .collection(role.collectionName)
            .get();

        for (final doc in snapshot.docs) {
          final userId = doc.data()['userId'] as String?;
          if (userId == null || userId.isEmpty) continue;

          final userProfile = await _getUserProfile(userId);
          if (userProfile == null) continue;

          fetchedUsers.add(userProfile);
          fetchedUserToRole[userId] = role;
        }
      }

      fetchedUsers.sort((a, b) {
        final aRole = fetchedUserToRole[a.uid];
        final bRole = fetchedUserToRole[b.uid];

        final roleCompare =
            (aRole?.index ?? 999).compareTo(bRole?.index ?? 999);
        if (roleCompare != 0) return roleCompare;

        return a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            );
      });

      final startIndex = replace ? 0 : state.users.length;
      if (startIndex >= fetchedUsers.length) {
        state = state.copyWith(
          event: event,
          currentUserRole: currentUserRole,
          isOwner: true,
          hasMore: false,
          error: null,
        );
        return;
      }

      final endIndex = (startIndex + pageSize).clamp(0, fetchedUsers.length);
      final pageUsers = fetchedUsers.sublist(startIndex, endIndex);

      final newUsers = replace ? pageUsers : [...state.users, ...pageUsers];
      final newUserToRole = replace
          ? fetchedUserToRole
          : {...state.userToRole, ...fetchedUserToRole};

      state = state.copyWith(
        event: event,
        currentUserRole: currentUserRole,
        users: newUsers,
        userToRole: newUserToRole,
        isOwner: true,
        hasMore: endIndex < fetchedUsers.length,
        error: null,
      );
    } catch (error, stackTrace) {
      debugPrint('EventRolesNotifier error: $error\n$stackTrace');
      state = state.copyWith(
        error: error,
        hasMore: false,
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
      await _assertOwner();

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

      state = state.copyWith(
        users: state.users.where((user) => user.uid != userId).toList(),
        userToRole: Map<String, EventRole>.from(state.userToRole)
          ..remove(userId),
        error: null,
      );

      if (state.users.length < pageSize && state.hasMore) {
        await loadMore();
      }
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
  (eventId) => EventRolesNotifier(eventId),
);