import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/models/event.dart';
import 'package:crowdpass/providers/auth_provider.dart';
import 'package:crowdpass/providers/firestore_provider.dart';

/// Filters for user events (currently supports date range filtering)
class UserEventsFilters {
  final DateTimeRange? dates;

  const UserEventsFilters({this.dates});

  UserEventsFilters copyWith({DateTimeRange? dates}) {
    return UserEventsFilters(dates: dates ?? this.dates);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is UserEventsFilters && other.dates == dates);
  }

  @override
  int get hashCode => dates.hashCode;
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
    // Auto-load events on initialization
    Future.microtask(refresh);
    return const UserEventsState();
  }

  /// Update filters and refresh events
  void setFilters(UserEventsFilters newFilters) {
    if (state.filters == newFilters) return;
    state = state.copyWith(filters: newFilters);
    Future.microtask(refresh);
  }

  /// Clear all filters and refresh
  void clearFilters() {
    setFilters(const UserEventsFilters());
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

      // Step 2: Fetch all event IDs and roles where user has a role (owner, admin, staff, guest, etc.)
      // Uses collectionGroup query to search subcollections across all events
      final userEventRoles = await _getUserEventRoles(user.uid);
      if (userEventRoles.isEmpty) {
        state = state.copyWith(
          events: const [],
          eventToRole: const {},
          hasMore: false,
        );
        return;
      }

      final userEventIds = userEventRoles.keys.toList();

      // Step 3: Build query for event documents with pagination and filters
      Query<Map<String, dynamic>> query = _firestore
          .collection('events')
          .where(FieldPath.documentId, whereIn: userEventIds);

      // Apply date range filter if specified
      final filters = state.filters;
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

      // Step 4: Sort and apply pagination cursor
      query = query.orderBy('dates.start', descending: false);

      if (!replace && state.events.isNotEmpty) {
        // For loadMore: start after the last event's start date
        final lastEvent = state.events.last;
        query = query.startAfter([lastEvent.dates.start.toIso8601String()]);
      }

      // Step 5: Limit to page size
      query = query.limit(pageSize);

      // Step 6: Fetch and parse documents
      final snapshot = await query.get();
      final docs = snapshot.docs;

      final fetchedEvents = docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return Event.fromJson(data);
      }).toList();

      // Step 7: Update state with new events, roles, and pagination status
      final nextEvents = replace
          ? fetchedEvents
          : [...state.events, ...fetchedEvents];

      final nextRoles = replace
          ? userEventRoles
          : {...state.eventToRole, ...userEventRoles};

      state = state.copyWith(
        events: nextEvents,
        eventToRole: nextRoles,
        hasMore: docs.length == pageSize, // More if we got a full page
      );
    } catch (error, stackTrace) {
      debugPrint('UserEventsNotifier error: $error\n$stackTrace');
      state = state.copyWith(error: error, hasMore: false);
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
  ///
  /// Expected Firestore structure:
  /// events/{eventId}/owners/{docId} → { userId: "user123" }
  /// events/{eventId}/admins/{docId} → { userId: "user123" }
  /// events/{eventId}/guests/{docId} → { userId: "user123" }
  /// etc.
  Future<Map<String, EventRole>> _getUserEventRoles(String userId) async {
    final eventRoles = <String, EventRole>{};

    for (final role in EventRole.values) {
      // Query subcollection by role name (owners, admins, staff, guests, security, vendors, volunteers)
      final snapshot = await _firestore
          .collectionGroup(role.collectionName)
          .where('userId', isEqualTo: userId)
          .get();

      // Extract event IDs and map to role by navigating up the hierarchy
      for (final doc in snapshot.docs) {
        final eventRef = doc.reference.parent.parent; // Navigate: role subcollection → event
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