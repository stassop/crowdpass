import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/models/event.dart';
import 'package:crowdpass/providers/auth_provider.dart';
import 'package:crowdpass/providers/firestore_provider.dart';

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
  final Map<String, EventRole> eventToRole; // Map eventId → user's role in that event
  final UserEventsFilters filters;
  final bool isLoading;
  final bool hasMore; // Indicates if more events can be loaded
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

/// Notifier for managing user's events (where they have any role: owner, admin, staff, guest, etc.)
class UserEventsNotifier extends Notifier<UserEventsState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const int pageSize = 30;

  @override
  UserEventsState build() {
    // Auto-load events on initialization with default date range (now + 1 month)
    Future.microtask(() {
      final now = DateTime.now();
      final oneMonthLater = now.add(const Duration(days: 30));
      final defaultRange = DateTimeRange(start: now, end: oneMonthLater);
      setFilters(UserEventsFilters(dates: defaultRange));
    });
    return const UserEventsState();
  }

  /// Update filters and refresh events
  void setFilters(UserEventsFilters newFilters) {
    if (state.filters == newFilters) return;
    state = state.copyWith(filters: newFilters);
    Future.microtask(refresh);
  }

  /// Set role filter (null to clear)
  void setRoleFilter(EventRole? role) {
    setFilters(state.filters.copyWith(role: role));
  }

  /// Clear all filters and refresh
  void clearFilters() {
    final now = DateTime.now();
    final oneMonthLater = now.add(const Duration(days: 30));
    final defaultRange = DateTimeRange(start: now, end: oneMonthLater);
    setFilters(UserEventsFilters(dates: defaultRange));
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

      // Step 2: Build base query for events
      final filters = state.filters;
      Query<Map<String, dynamic>> query = _firestore.collection('events');

      // If role is filtered, query the specific role subcollection
      if (filters.role != null) {
        query = _firestore
            .collectionGroup(filters.role!.collectionName)
            .where('userId', isEqualTo: user.uid);
      } else {
        // Query all events where user has any role
        // We'll need to fetch from all role subcollections and deduplicate
        final allEventIds = await _getUserEventIds(user.uid);
        if (allEventIds.isEmpty) {
          state = state.copyWith(
            events: const [],
            eventToRole: const {},
            hasMore: false,
          );
          return;
        }
        
        // For "all roles" case, we need to fetch the role mapping and then query events
        final userEventRoles = await _getUserEventRoles(user.uid);
        query = _firestore
            .collection('events')
            .where(FieldPath.documentId, whereIn: allEventIds.toList());
        
        // Store roles for later use
        state = state.copyWith(
          eventToRole: userEventRoles,
        );
      }

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

      final fetchedEvents = docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return Event.fromJson(data);
      }).toList();

      // Get roles if not already fetched
      Map<String, EventRole> eventRoles = state.eventToRole;
      if (filters.role == null && state.eventToRole.isEmpty) {
        eventRoles = await _getUserEventRoles(user.uid);
      } else if (filters.role != null) {
        // For single role case, all events have the same role
        eventRoles = {
          for (final event in fetchedEvents)
            event.id: filters.role!
        };
      }

      // Update state
      final nextEvents = replace
          ? fetchedEvents
          : [...state.events, ...fetchedEvents];

      final nextRoles = replace
          ? eventRoles
          : {...state.eventToRole, ...eventRoles};

      state = state.copyWith(
        events: nextEvents,
        eventToRole: nextRoles,
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