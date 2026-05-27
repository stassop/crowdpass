import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/providers/auth_provider.dart';

import 'package:crowdpass/models/event.dart' show EventRole;

class EventRolesState {
  final Map<EventRole, List<String>> roles;

  const EventRolesState({this.roles = const {}});

  EventRolesState copyWith({Map<EventRole, List<String>>? roles}) {
    return EventRolesState(roles: roles ?? this.roles);
  }
}

class EventRolesNotifier extends Notifier<EventRolesState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late String _eventId;

  @override
  EventRolesState build() => const EventRolesState();

  CollectionReference<Map<String, dynamic>> _roleCollection(EventRole role) {
    return _firestore.collection('events').doc(_eventId).collection(role.name);
  }

  Future<void> addUserToRole(EventRole role, String userId) async {
    final docRef = _roleCollection(role).doc(userId);

    await docRef.set({
      'userId': userId,
      'role': role.name,
      'assignedAt': FieldValue.serverTimestamp(),
    });

    addUserToRoleLocal(role, userId);
  }

  Future<void> removeUserFromRole(EventRole role, String userId) async {
    final docRef = _roleCollection(role).doc(userId);

    await docRef.delete();
    removeUserFromRoleLocal(role, userId);
  }

  Future<void> moveUserToRole({
    required EventRole fromRole,
    required EventRole toRole,
    required String userId,
  }) async {
    final batch = _firestore.batch();

    final fromRef = _roleCollection(fromRole).doc(userId);
    final toRef = _roleCollection(toRole).doc(userId);

    batch.delete(fromRef);
    batch.set(toRef, {
      'userId': userId,
      'role': toRole.name,
      'assignedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    removeUserFromRoleLocal(fromRole, userId);
    addUserToRoleLocal(toRole, userId);
  }

  Future<List<String>> fetchRoleUsers(EventRole role) async {
    final snapshot = await _roleCollection(role).get();
    final userIds = snapshot.docs.map((doc) => doc.id).toList();

    setRoleUsersLocal(role, userIds);
    return userIds;
  }

  void setRoleUsersLocal(EventRole role, List<String> userIds) {
    state = state.copyWith(
      roles: {
        ...state.roles,
        role: List<String>.from(userIds),
      },
    );
  }

  void addUserToRoleLocal(EventRole role, String userId) {
    final existing = state.roles[role] ?? const <String>[];

    if (existing.contains(userId)) return;

    state = state.copyWith(
      roles: {
        ...state.roles,
        role: [...existing, userId],
      },
    );
  }

  void removeUserFromRoleLocal(EventRole role, String userId) {
    final existing = state.roles[role] ?? const <String>[];

    state = state.copyWith(
      roles: {
        ...state.roles,
        role: existing.where((id) => id != userId).toList(),
      },
    );
  }

  bool hasUserInRole(EventRole role, String userId) {
    return (state.roles[role] ?? const <String>[]).contains(userId);
  }

  List<String> usersForRole(EventRole role) {
    return state.roles[role] ?? const <String>[];
  }
}

final eventRolesProvider =
    NotifierProvider.family<EventRolesNotifier, EventRolesState, String>(
  (eventId) => EventRolesNotifier().._eventId = eventId,
);
