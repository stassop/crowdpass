import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/models/event.dart';
import 'package:crowdpass/providers/auth_provider.dart';

/// Filters for user events (supports date range and single role filtering)
class UserEventsFilters {
  final DateTimeRange? dates;
  final EventRole? role; // Single role filter, null means all roles

  const UserEventsFilters({
    this.dates,
    this.role,
  });

  UserEventsFilters copyWith({
    DateTimeRange? dates,
    EventRole? role,
  }) {
    return UserEventsFilters(
      dates: dates ?? this.dates,
      role: role ?? this.role,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is UserEventsFilters &&
            other.dates == dates &&
            other.role == role);
  }

  @override
  int get hashCode => Object.hash(dates, role);
}

/// State for user events with pagination and error handling
class UserEventsState {
  final List<Event> events;
  final Map<String, EventRole> eventToRole;
  final UserEventsFilters filters;
  final bool isLoading;
  final bool hasMore;
  final Object? error;

  const UserEventsState({
    this.events = const [],
    this.eventToRole = const {},
    this.filters = const UserEventsFilters(),
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  UserEventsState copyWith({
    List<Event>? events,
    Map<String, EventRole>? eventToRole,
    UserEventsFilters? filters,
    bool? isLoading,
    bool? hasMore,
    Object? error,
  }) {
    return UserEventsState(
      events: events ?? this.events,
      eventToRole: eventToRole ?? this.eventToRole,
      filters: filters ?? this.filters,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

/// Notifier for managing user's events
class UserEventsNotifier extends Notifier<UserEventsState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const int pageSize = 30;

  @override
  UserEventsState build() {
    Future.microtask(() {
      final now = DateTime.now();
      final oneMonthLater = now.add(const Duration(days: 30));
      final defaultRange = DateTimeRange(start: now, end: oneMonthLater);
      setFilters(UserEventsFilters(dates: defaultRange));
    });
    return const UserEventsState();
  }

  void setFilters(UserEventsFilters newFilters) {
    if (state.filters == newFilters) return;
    state = state.copyWith(filters: newFilters);
    Future.microtask(refresh);
  }

  void setRoleFilter(EventRole? role) {
    setFilters(state.filters.copyWith(role: role));
  }

  void clearFilters() {
    final now = DateTime.now();
    final oneMonthLater = now.add(const Duration(days: 30));
    final defaultRange = DateTimeRange(start: now, end: oneMonthLater);
    setFilters(UserEventsFilters(dates: defaultRange));
  }

  Future<void> refresh() async {
    state = state.copyWith(
      events: const [],
      eventToRole: const {},
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

  /// Internal method: Fetch all user events, filter in-memory by date and role
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

      final filters = state.filters;

      // Step 1: Get all event IDs and roles for this user
      final userEventRoles = await _getUserEventRoles(user.uid);
      if (userEventRoles.isEmpty) {
        state = state.copyWith(
          events: const [],
          eventToRole: const {},
          hasMore: false,
        );
        return;
      }

      final eventIds = userEventRoles.keys.toList();

      // Step 2: Fetch all event documents (split into chunks for whereIn limit)
      final allEvents = <Event>[];
      for (final chunk in _chunk(eventIds, 10)) {
        final snapshot = await _firestore
            .collection('events')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final doc in snapshot.docs) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          allEvents.add(Event.fromJson(data));
        }
      }

      if (allEvents.isEmpty) {
        state = state.copyWith(
          events: const [],
          eventToRole: const {},
          hasMore: false,
        );
        return;
      }

      // Step 3: Filter by date range in-memory
      List<Event> filteredEvents = allEvents;
      if (filters.dates != null) {
        filteredEvents = allEvents
            .where((event) =>
                event.dates.end.isAfter(filters.dates!.start) &&
                event.dates.start.isBefore(filters.dates!.end))
            .toList();
      }

      // Step 4: Filter by role in-memory
      if (filters.role != null) {
        filteredEvents = filteredEvents
            .where((event) => userEventRoles[event.id] == filters.role)
            .toList();
      }

      // Step 5: Sort by date
      filteredEvents.sort((a, b) => a.dates.start.compareTo(b.dates.start));

      // Step 6: Apply pagination
      List<Event> paginatedEvents = filteredEvents;
      if (!replace && state.events.isNotEmpty) {
        final lastEvent = state.events.last;
        paginatedEvents = filteredEvents
            .where((e) => e.dates.start.isAfter(lastEvent.dates.start))
            .take(pageSize)
            .toList();
      } else {
        paginatedEvents = filteredEvents.take(pageSize).toList();
      }

      final nextEvents = replace
          ? paginatedEvents
          : [...state.events, ...paginatedEvents];

      // Build role map for displayed events
      final nextRoles = <String, EventRole>{};
      for (final event in nextEvents) {
        final role = userEventRoles[event.id];
        if (role != null) {
          nextRoles[event.id] = role;
        }
      }

      state = state.copyWith(
        events: nextEvents,
        eventToRole: nextRoles,
        hasMore: paginatedEvents.length == pageSize,
      );
    } catch (error, stackTrace) {
      debugPrint('UserEventsNotifier error: $error\n$stackTrace');
      state = state.copyWith(error: error, hasMore: false);
    }
  }

  /// Fetch all event IDs and roles where user has any role
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

  /// Split list into chunks
  List<List<String>> _chunk(List<String> values, int size) {
    final chunks = <List<String>>[];
    for (var i = 0; i < values.length; i += size) {
      final end = (i + size < values.length) ? i + size : values.length;
      chunks.add(values.sublist(i, end));
    }
    return chunks;
  }
}

final userEventsProvider =
    NotifierProvider<UserEventsNotifier, UserEventsState>(
  UserEventsNotifier.new,
);