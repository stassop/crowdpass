import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/models/event.dart';
import 'package:crowdpass/providers/auth_provider.dart';

/// Filters for user events (supports date range and multiple role filtering)
class UserEventsFilters {
  final DateTimeRange? dates;
  final Set<EventRole> roles; // Multiple roles filter, empty set means all roles

  const UserEventsFilters({
    this.dates,
    Set<EventRole>? roles,
  }) : roles = roles ?? const <EventRole>{...EventRole.values};

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

/// State for user events with pagination and error handling
class UserEventsState {
  final List<Event> events;
  final Map<String, EventRole> eventToRole; // Map eventId → user's role in that event
  final UserEventsFilters filters;
  final DateTime? earliestDate; // Earliest event user ever participated in (across all time)
  final DateTime? latestDate; // Latest event user ever participated in (across all time)
  final bool isLoading;
  final bool hasMore; // Indicates if more events can be loaded
  final Object? error;

  const UserEventsState({
    this.events = const [],
    this.eventToRole = const {},
    this.filters = const UserEventsFilters(),
    this.earliestDate,
    this.latestDate,
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  UserEventsState copyWith({
    List<Event>? events,
    Map<String, EventRole>? eventToRole,
    UserEventsFilters? filters,
    DateTime? earliestDate,
    DateTime? latestDate,
    bool? isLoading,
    bool? hasMore,
    Object? error,
  }) {
    return UserEventsState(
      events: events ?? this.events,
      eventToRole: eventToRole ?? this.eventToRole,
      filters: filters ?? this.filters,
      earliestDate: earliestDate ?? this.earliestDate,
      latestDate: latestDate ?? this.latestDate,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

/// Notifier for managing user's events (where they have any role: owner, admin, staff, guest, etc.)
class UserEventsNotifier extends Notifier<UserEventsState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const int pageSize = 10;

  @override
  UserEventsState build() {
    return const UserEventsState();
  }

  DateTimeRange _defaultDateRange({
    DateTime? earliestDate,
    DateTime? latestDate,
  }) {
    final defaultEnd = latestDate ?? DateTime.now();
    final thirtyDaysBack = defaultEnd.subtract(const Duration(days: 30));
    final defaultStart = earliestDate != null &&
            thirtyDaysBack.isBefore(earliestDate)
        ? earliestDate
        : thirtyDaysBack;

    return DateTimeRange(start: defaultStart, end: defaultEnd);
  }

  /// Update filters and refresh events
  void setFilters(UserEventsFilters newFilters) {
    if (state.filters == newFilters) return;
    state = state.copyWith(filters: newFilters);
    Future.microtask(refresh);
  }

  /// Toggle a role in the filter set
  void toggleRoleFilter(EventRole role) {
    final updatedRoles = {...state.filters.roles};
    if (updatedRoles.contains(role)) {
      updatedRoles.remove(role);
    } else {
      updatedRoles.add(role);
    }
    setFilters(state.filters.copyWith(roles: updatedRoles));
  }

  /// Clear all filters and refresh with defaults
  void resetFilters() {
    setFilters(UserEventsFilters(
      dates: _defaultDateRange(
        earliestDate: state.earliestDate,
        latestDate: state.latestDate,
      ),
    ));
  }

  /// Refresh: Clear all events and reload from the beginning
  Future<void> refresh() async {
    await loadMore(replace: true);
  }

  /// Load events. If replace=true, reload from the beginning.
  Future<void> loadMore({bool replace = false}) async {
    if (state.isLoading) return;
    if (!replace && !state.hasMore) return;

    if (replace) {
      state = state.copyWith(
        events: const [],
        eventToRole: const {},
        isLoading: true,
        hasMore: true,
        error: null,
      );
    } else {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final user = await ref.read(authProvider.future);
      if (user == null) {
        state = state.copyWith(
          events: const [],
          eventToRole: const {},
          hasMore: false,
          isLoading: false,
          error: 'User not authenticated',
        );
        return;
      }

      // Fetch user's roles for all their events in a single batch
      final userEventRoles = await _getUserEventRoles(user.uid);

      // Get user event IDs for quick lookup
      final userEventIds = userEventRoles.keys.toList();

      // We can't have an empty userEventIds list for Firestore queries, so handle that case
      if (userEventIds.isEmpty) {
        state = state.copyWith(
          events: const [],
          eventToRole: const {},
          hasMore: false,
          isLoading: false,
          error: null,
        );
        return;
      }

      var filters = state.filters;

      if (replace) {
        final earliest = await _getEarliestEventDate(userEventIds);
        final latest = await _getLatestEventDate(userEventIds);

        if (earliest != state.earliestDate ||
            latest != state.latestDate) {
          state = state.copyWith(
            filters: filters.copyWith(
              dates: _defaultDateRange(
                earliestDate: earliest,
                latestDate: latest,
              ),
            ),
            earliestDate: earliest,
            latestDate: latest,
          );
        }
      }

      // We can't use FieldPath.documentId here because if multiple where query limitation
      Query<Map<String, dynamic>> query = _firestore
          .collection('events')
          .where('id', whereIn: userEventIds);

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

      // Parse events and filter by selected roles
      final filteredEvents = <Event>[];
      final filteredEventRoles = <String, EventRole>{};

      for (final doc in docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        final event = Event.fromJson(data);

        // Get user's role in this event
        final userRole = userEventRoles[event.id];

        // Include event only if user has a role and that role is selected
        if (userRole != null && filters.roles.contains(userRole)) {
          filteredEvents.add(event);
          filteredEventRoles[event.id] = userRole;
        }
      }

      final newEvents = replace
          ? filteredEvents
          : [...state.events, ...filteredEvents];

      final newRoles = replace
          ? filteredEventRoles
          : {...state.eventToRole, ...filteredEventRoles};

      state = state.copyWith(
        events: newEvents,
        eventToRole: newRoles,
        hasMore: docs.length == pageSize,
        isLoading: false,
        error: null,
      );
    } catch (error, stackTrace) {
      debugPrint('UserEventsNotifier error: $error\n$stackTrace');
      state = state.copyWith(
        isLoading: false,
        hasMore: false,
        error: error,
      );
    }
  }

  /// Fetch all event IDs mapped to their roles for the user
  /// Returns: Map<eventId, EventRole>
  ///
  /// How it works:
  /// 1. Iterate through all EventRole values (owner, admin, staff, guest, etc.)
  /// 2. Use collectionGroup() to query all subcollections named by role (e.g., "owners", "admins")
  ///    across ALL events simultaneously
  /// 3. Filter documents to only those matching the current userId
  /// 4. Navigate up: doc.reference.parent.parent gives the event document reference
  /// 5. Extract event IDs and map to their corresponding role
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

  /// Fetch the earliest event date the user has ever participated in
  /// This queries ALL user events without date filtering
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

  /// Fetch the latest event date the user has ever participated in
  /// This queries ALL user events without date filtering
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

/// Provider for user events notifier
final userEventsProvider =
    NotifierProvider<UserEventsNotifier, UserEventsState>(
  UserEventsNotifier.new,
);