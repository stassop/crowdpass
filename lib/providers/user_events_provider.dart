import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/models/event.dart';
import 'package:crowdpass/providers/auth_provider.dart';

class UserEventsFilters {
  final DateTimeRange? dates;
  final Set<EventRole> roles;

  const UserEventsFilters({
    this.dates,
    this.roles = const {},
  });

  UserEventsFilters copyWith({
    DateTimeRange? dates,
    Set<EventRole>? roles,
  }) {
    return UserEventsFilters(
      dates: dates ?? this.dates,
      roles: roles ?? this.roles,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is UserEventsFilters &&
            other.dates == dates &&
            setEquals(other.roles, roles));
  }

  @override
  int get hashCode => Object.hash(dates, Object.hashAllUnordered(roles));
}

class UserEventsState {
  final List<Event> events;
  final Map<String, EventRole> eventToRole;
  final UserEventsFilters filters;
  final DateTime? earliestEventDate;
  final DateTime? latestEventDate;
  final bool isLoading;
  final bool hasMore;
  final Object? error;

  const UserEventsState({
    this.events = const [],
    this.eventToRole = const {},
    this.filters = const UserEventsFilters(),
    this.earliestEventDate,
    this.latestEventDate,
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  UserEventsState copyWith({
    List<Event>? events,
    Map<String, EventRole>? eventToRole,
    UserEventsFilters? filters,
    DateTime? earliestEventDate,
    DateTime? latestEventDate,
    bool? isLoading,
    bool? hasMore,
    Object? error,
  }) {
    return UserEventsState(
      events: events ?? this.events,
      eventToRole: eventToRole ?? this.eventToRole,
      filters: filters ?? this.filters,
      earliestEventDate: earliestEventDate ?? this.earliestEventDate,
      latestEventDate: latestEventDate ?? this.latestEventDate,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

class UserEventsNotifier extends Notifier<UserEventsState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const int pageSize = 10;
  bool _initialized = false;

  @override
  UserEventsState build() {
    if (!_initialized) {
      _initialized = true;
      Future.microtask(refresh);
    }

    return const UserEventsState(
      filters: UserEventsFilters(
        roles: {},
      ),
    );
  }

  void setFilters(UserEventsFilters newFilters) {
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
    final latest = state.latestEventDate ?? DateTime.now();
    final defaultStart = latest.subtract(const Duration(days: 30));
    final defaultRange = DateTimeRange(start: defaultStart, end: latest);

    setFilters(UserEventsFilters(
      dates: defaultRange,
      roles: EventRole.values.toSet(),
    ));
  }

  Future<void> refresh() async {
    if (state.isLoading) return;

    state = state.copyWith(
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
          events: const [],
          eventToRole: const {},
          hasMore: false,
          error: 'User not authenticated',
        );
        return;
      }

      final userEventRoles = await _getUserEventRoles(user.uid);
      final userEventIds = userEventRoles.keys.toList();

      if (userEventIds.isEmpty) {
        state = state.copyWith(
          events: const [],
          eventToRole: const {},
          hasMore: false,
          error: null,
        );
        return;
      }

      if (replace) {
        final earliest = await _getEarliestEventDate(userEventIds);
        final latest = await _getLatestEventDate(userEventIds);

        state = state.copyWith(
          earliestEventDate: earliest,
          latestEventDate: latest,
        );
      }

      final filters = state.filters;

      Query<Map<String, dynamic>> query = _firestore
          .collection('events')
          .where(FieldPath.documentId, whereIn: userEventIds);

      if (filters.dates != null) {
        query = query.where(
          'dates.start',
          isGreaterThanOrEqualTo: filters.dates!.start.toIso8601String(),
        );
        query = query.where(
          'dates.start',
          isLessThanOrEqualTo: filters.dates!.end.toIso8601String(),
        );
      }

      query = query.orderBy('dates.start', descending: false);

      if (!replace && state.events.isNotEmpty) {
        final lastEvent = state.events.last;
        query = query.startAfter([lastEvent.dates.start.toIso8601String()]);
      }

      query = query.limit(pageSize);

      final snapshot = await query.get();
      final docs = snapshot.docs;

      final filteredEvents = <Event>[];
      final filteredEventRoles = <String, EventRole>{};

      for (final doc in docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        final event = Event.fromJson(data);

        final userRole = userEventRoles[event.id];
        if (userRole != null) {
          final rolesFilter = filters.roles;
          if (rolesFilter.isEmpty || rolesFilter.contains(userRole)) {
            filteredEvents.add(event);
            filteredEventRoles[event.id] = userRole;
          }
        }
      }

      state = state.copyWith(
        events: replace ? filteredEvents : [...state.events, ...filteredEvents],
        eventToRole: replace
            ? filteredEventRoles
            : {...state.eventToRole, ...filteredEventRoles},
        hasMore: docs.length == pageSize,
        error: null,
      );
    } catch (error, stackTrace) {
      debugPrint('UserEventsNotifier error: $error\n$stackTrace');
      state = state.copyWith(error: error, hasMore: false);
    }
  }

  Future<Map<String, EventRole>> _getUserEventRoles(String userId) async {
    final eventRoles = <String, EventRole>{};

    for (final role in EventRole.values) {
      final snapshot = await _firestore
          .collectionGroup(role.collectionName)
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in snapshot.docs) {
        final eventRef = doc.reference.parent.parent;
        if (eventRef != null) {
          eventRoles[eventRef.id] = role;
        }
      }
    }

    return eventRoles;
  }

  Future<DateTime?> _getEarliestEventDate(List<String> userEventIds) async {
    try {
      final snapshot = await _firestore
          .collection('events')
          .where(FieldPath.documentId, whereIn: userEventIds)
          .orderBy('dates.start', descending: false)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      final data = snapshot.docs.first.data();
      final startDateStr = data['dates']['start'] as String?;
      if (startDateStr == null) return null;
      return DateTime.tryParse(startDateStr);
    } catch (error, stackTrace) {
      debugPrint('Error fetching earliest event date: $error\n$stackTrace');
      return null;
    }
  }

  Future<DateTime?> _getLatestEventDate(List<String> userEventIds) async {
    try {
      final snapshot = await _firestore
          .collection('events')
          .where(FieldPath.documentId, whereIn: userEventIds)
          .orderBy('dates.start', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      final data = snapshot.docs.first.data();
      final startDateStr = data['dates']['start'] as String?;
      if (startDateStr == null) return null;
      return DateTime.tryParse(startDateStr);
    } catch (error, stackTrace) {
      debugPrint('Error fetching latest event date: $error\n$stackTrace');
      return null;
    }
  }
}

final userEventsProvider =
    NotifierProvider<UserEventsNotifier, UserEventsState>(
  UserEventsNotifier.new,
);