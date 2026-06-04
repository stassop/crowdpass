import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/models/event.dart';
import 'package:crowdpass/providers/auth_provider.dart';
import 'package:crowdpass/providers/firestore_provider.dart';

/// Filters for user events (supports date range and multiple role filtering)
class UserEventsFilters {
  final DateTimeRange? dates;
  final Set<EventRole> roles; // Multiple roles filter, empty set means all roles

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
            other.roles == roles);
  }

  @override
  int get hashCode => Object.hash(dates, roles);
}

/// State for user events with pagination and error handling
class UserEventsState {
  final List<Event> events;
  final Map<String, EventRole> eventToRole; // Map eventId → user's role in that event
  final UserEventsFilters filters;
  final DateTime? earliestEventDate; // Start date of earliest event user participated in
  final bool isLoading;
  final bool hasMore; // Indicates if more events can be loaded
  final Object? error;

  const UserEventsState({
    this.events = const [],
    this.eventToRole = const {},
    this.filters = const UserEventsFilters(),
    this.earliestEventDate,
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  UserEventsState copyWith({
    List<Event>? events,
    Map<String, EventRole>? eventToRole,
    UserEventsFilters? filters,
    DateTime? earliestEventDate,
    bool? isLoading,
    bool? hasMore,
    Object? error,
  }) {
    return UserEventsState(
      events: events ?? this.events,
      eventToRole: eventToRole ?? this.eventToRole,
      filters: filters ?? this.filters,
      earliestEventDate: earliestEventDate ?? this.earliestEventDate,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

/// Notifier for managing user's events (where they have any role: owner, admin, staff, guest, etc.)
class UserEventsNotifier extends Notifier<UserEventsState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const int pageSize = 30;

  @override
  UserEventsState build() {
    // Auto-load events on initialization with default settings
    Future.microtask(() {
      final now = DateTime.now();
      final oneMonthLater = now.add(const Duration(days: 30));
      final defaultRange = DateTimeRange(start: now, end: oneMonthLater);
      
      // By default, all roles are selected
      final defaultFilters = UserEventsFilters(
        dates: defaultRange,
        roles: EventRole.values.toSet(),
      );
      
      setFilters(defaultFilters);
    });
    return const UserEventsState();
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
  void clearFilters() {
    final now = DateTime.now();
    final oneMonthLater = now.add(const Duration(days: 30));
    final defaultRange = DateTimeRange(start: now, end: oneMonthLater);
    final defaultFilters = UserEventsFilters(
      dates: defaultRange,
      roles: EventRole.values.toSet(),
    );
    setFilters(defaultFilters);
  }

  /// Refresh: Clear all events and reload from the beginning
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

  /// Load more: Append next page of events (pagination)
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true, error: null);
    await _loadMoreInternal(replace: false);
    state = state.copyWith(isLoading: false);
  }

  /// Internal method: Handles pagination logic (replace=true for refresh, false for loadMore)
  Future<void> _loadMoreInternal({required bool replace}) async {
    try {
      // Step 1: Get current authenticated user
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

      // Step 2: Get all event IDs where user has any role
      final userEventIds = await _getUserEventIds(user.uid);
      if (userEventIds.isEmpty) {
        state = state.copyWith(
          events: const [],
          eventToRole: const {},
          hasMore: false,
          earliestEventDate: null,
        );
        return;
      }

      // Step 3: Get role mapping for all user's events (only once)
      final userEventRoles = await _getUserEventRoles(user.uid);

      // Step 4: Fetch events, filtered by date range
      final filters = state.filters;
      Query<Map<String, dynamic>> query = _firestore
          .collection('events')
          .where(FieldPath.documentId, whereIn: userEventIds.toList());

      // Apply date range filter if specified
      if (filters.dates != null) {
        query = query
            .where(
              'dates.end',
              isGreaterThanOrEqualTo: filters.dates!.start.toIso8601String(),
            )
            .where(
              'dates.start',
              isLessThanOrEqualTo: filters.dates!.end.toIso8601String(),
            );
      }

      // Sort by start date
      query = query.orderBy('dates.start', descending: false);

      // Apply pagination cursor
      if (!replace && state.events.isNotEmpty) {
        final lastEvent = state.events.last;
        query = query.startAfter([lastEvent.dates.start.toIso8601String()]);
      }

      // Limit to page size
      query = query.limit(pageSize);

      final snapshot = await query.get();
      final docs = snapshot.docs;

      // Step 5: Parse events and filter by selected roles
      final filteredEvents = <Event>[];
      final filteredEventRoles = <String, EventRole>{};

      for (final doc in docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        final event = Event.fromJson(data);

        // Get user's role in this event
        final userRole = userEventRoles[event.id];
        
        // Include event only if user has a role and that role is selected
        // (empty roles set means all roles are selected)
        if (userRole != null) {
          final rolesFilter = filters.roles;
          if (rolesFilter.isEmpty || rolesFilter.contains(userRole)) {
            filteredEvents.add(event);
            filteredEventRoles[event.id] = userRole;
          }
        }
      }

      // Step 6: Compute earliest event date (only on first load)
      DateTime? earliest = state.earliestEventDate;
      if (replace && filteredEvents.isNotEmpty) {
        earliest = filteredEvents.fold<DateTime>(
          filteredEvents.first.dates.start,
          (prev, event) => event.dates.start.isBefore(prev)
              ? event.dates.start
              : prev,
        );
      }

      // Step 7: Update state
      final nextEvents = replace
          ? filteredEvents
          : [...state.events, ...filteredEvents];

      final nextRoles = replace
          ? filteredEventRoles
          : {...state.eventToRole, ...filteredEventRoles};

      state = state.copyWith(
        events: nextEvents,
        eventToRole: nextRoles,
        earliestEventDate: earliest,
        hasMore: docs.length == pageSize,
      );
    } catch (error, stackTrace) {
      debugPrint('UserEventsNotifier error: $error\n$stackTrace');
      state = state.copyWith(error: error, hasMore: false);
    }
  }

  /// Fetch all event IDs where user has any role
  Future<Set<String>> _getUserEventIds(String userId) async {
    final eventIds = <String>{};

    for (final role in EventRole.values) {
      final snapshot = await _firestore
          .collectionGroup(role.collectionName)
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in snapshot.docs) {
        final eventRef = doc.reference.parent.parent;
        if (eventRef != null) {
          eventIds.add(eventRef.id);
        }
      }
    }

    return eventIds;
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
  ///
  /// Expected Firestore structure:
  /// events/{eventId}/owners/{docId} → { userId: "user123" }
  /// events/{eventId}/admins/{docId} → { userId: "user123" }
  /// events/{eventId}/guests/{docId} → { userId: "user123" }
  /// etc.
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
}

/// Provider for user events notifier
final userEventsProvider =
    NotifierProvider<UserEventsNotifier, UserEventsState>(
  UserEventsNotifier.new,
);
