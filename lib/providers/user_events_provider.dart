import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/models/event.dart';
import 'package:crowdpass/providers/auth_provider.dart';

/// Filters for user events
class UserEventsFilters {
  final DateTimeRange? dates;
  final Set<EventRole> roles; // Empty set means all roles

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
  int get hashCode => Object.hash(
    dates,
    Object.hashAll(roles.toList()..sort((a, b) => a.index.compareTo(b.index))),
  );
}

/// State for user events
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
      setFilters(UserEventsFilters(
        dates: defaultRange,
        roles: Set.from(EventRole.values),
      ));
    });
    return const UserEventsState();
  }

  void setFilters(UserEventsFilters newFilters) {
    if (state.filters == newFilters) return;
    state = state.copyWith(filters: newFilters);
    Future.microtask(refresh);
  }

  void toggleRoleFilter(EventRole role) {
    final Set<EventRole> nextRoles = Set.from(state.filters.roles);
    if (nextRoles.contains(role)) {
      nextRoles.remove(role);
    } else {
      nextRoles.add(role);
    }
    setFilters(state.filters.copyWith(roles: nextRoles));
  }

  void clearFilters() {
    final now = DateTime.now();
    final oneMonthLater = now.add(const Duration(days: 30));
    final defaultRange = DateTimeRange(start: now, end: oneMonthLater);
    setFilters(UserEventsFilters(
      dates: defaultRange,
      roles: Set.from(EventRole.values),
    ));
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
      
      debugPrint('Found ${userEventRoles.length} events for user ${user.uid}');
      debugPrint('Event roles: $userEventRoles');
      
      if (userEventRoles.isEmpty) {
        state = state.copyWith(
          events: const [],
          eventToRole: const {},
          hasMore: false,
        );
        return;
      }

      final eventIds = userEventRoles.keys.toList();

      // Step 2: Fetch ALL event documents in chunks
      final allEvents = <Event>[];
      
      for (int i = 0; i < eventIds.length; i += 10) {
        final end = (i + 10 < eventIds.length) ? i + 10 : eventIds.length;
        final chunk = eventIds.sublist(i, end);
        
        debugPrint('Fetching chunk: $chunk');
        
        final snapshot = await _firestore
            .collection('events')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        debugPrint('Got ${snapshot.docs.length} documents');

        for (final doc in snapshot.docs) {
          try {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] = doc.id;
            allEvents.add(Event.fromJson(data));
          } catch (e) {
            debugPrint('Error parsing event ${doc.id}: $e');
          }
        }
      }

      debugPrint('Total events fetched: ${allEvents.length}');

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
        debugPrint('Filtering by dates: ${filters.dates!.start} to ${filters.dates!.end}');
        filteredEvents = allEvents
            .where((event) {
              debugPrint('Event ${event.id} dates: ${event.dates.start} to ${event.dates.end}');
              return event.dates.end.isAfter(filters.dates!.start) &&
                  event.dates.start.isBefore(filters.dates!.end);
            })
            .toList();
        debugPrint('After date filter: ${filteredEvents.length} events');
      }

      // Step 4: Filter by roles in-memory
      if (filters.roles.isNotEmpty && filters.roles.length < EventRole.values.length) {
        debugPrint('Filtering by roles: ${filters.roles}');
        filteredEvents = filteredEvents
            .where((event) {
              final eventRole = userEventRoles[event.id];
              debugPrint('Event ${event.id} has role $eventRole, selected roles: ${filters.roles}');
              return filters.roles.contains(eventRole);
            })
            .toList();
        debugPrint('After role filter: ${filteredEvents.length} events');
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
      debugPrint('UserEventsNotifier error: $error');
      debugPrintStack(stackTrace: stackTrace);
      state = state.copyWith(error: error, hasMore: false);
    }
  }

  Future<Map<String, EventRole>> _getUserEventRoles(String userId) async {
    final eventRoles = <String, EventRole>{};

    for (final role in EventRole.values) {
      debugPrint('Querying ${role.collectionName} for userId $userId');
      
      final snapshot = await _firestore
          .collectionGroup(role.collectionName)
          .where('userId', isEqualTo: userId)
          .get();

      debugPrint('Found ${snapshot.docs.length} documents');

      for (final doc in snapshot.docs) {
        final eventRef = doc.reference.parent.parent;
        if (eventRef != null) {
          eventRoles[eventRef.id] = role;
          debugPrint('Added event ${eventRef.id} with role $role');
        }
      }
    }

    return eventRoles;
  }
}

final userEventsProvider =
    NotifierProvider<UserEventsNotifier, UserEventsState>(
  UserEventsNotifier.new,
);