import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/models/event.dart';

enum EventStatusFilter { past, current, upcoming, canceled }

class MyEventsFilters {
  final Set<EventStatusFilter> status;
  final DateTimeRange? dates;
  final bool isMonthly;

  const MyEventsFilters({
    this.status = const {},
    this.dates,
    this.isMonthly = false,
  });

  MyEventsFilters copyWith({
    Set<EventStatusFilter>? status,
    DateTimeRange? dates,
    bool? isMonthly,
  }) {
    return MyEventsFilters(
      status: status ?? this.status,
      dates: dates ?? this.dates,
      isMonthly: isMonthly ?? this.isMonthly,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is MyEventsFilters &&
            setEquals(other.status, status) &&
            other.dates == dates &&
            other.isMonthly == isMonthly);
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(status.toList()..sort((a, b) => a.index.compareTo(b.index))),
        dates,
        isMonthly,
      );
}

class MyEventsState {
  final List<Event> events;
  final MyEventsFilters filters;
  final bool isLoading;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final Object? error;

  const MyEventsState({
    this.events = const [],
    this.filters = const MyEventsFilters(),
    this.isLoading = false,
    this.hasMore = true,
    this.lastDocument,
    this.error,
  });

  MyEventsState copyWith({
    List<Event>? events,
    MyEventsFilters? filters,
    bool? isLoading,
    bool? hasMore,
    DocumentSnapshot<Map<String, dynamic>>? lastDocument,
    Object? error,
  }) {
    return MyEventsState(
      events: events ?? this.events,
      filters: filters ?? this.filters,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      lastDocument: lastDocument ?? this.lastDocument,
      error: error,
    );
  }
}

class MyEventsNotifier extends Notifier<MyEventsState> {
  MyEventsNotifier(this.companyId);

  final String companyId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const int pageSize = 30;

  @override
  MyEventsState build() {
    Future.microtask(refresh);
    return const MyEventsState();
  }

  /// Sets all filters at once and triggers a refresh if they changed.
  void setFilters(MyEventsFilters newFilters) {
    if (state.filters == newFilters) return;
    state = state.copyWith(filters: newFilters);
    refresh();
  }

  /// Toggles a single status filter and refreshes.
  void toggleStatusFilter(EventStatusFilter filter) {
    final Set<EventStatusFilter> nextFilters = Set.from(state.filters.status);
    if (nextFilters.contains(filter)) {
      nextFilters.remove(filter);
    } else {
      nextFilters.add(filter);
    }
    setFilters(state.filters.copyWith(status: nextFilters));
  }

  /// Resets the list and starts fetching from the first page.
  Future<void> refresh() async {
    if (state.isLoading) return;

    state = state.copyWith(
      events: const [],
      isLoading: true,
      hasMore: true,
      lastDocument: null,
      error: null,
    );

    await _fetchNextPage(isRefresh: true);
  }

  /// Loads the next set of events for pagination.
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true, error: null);
    await _fetchNextPage(isRefresh: false);
  }

  void clearFilters() {
    setFilters(const MyEventsFilters());
  }

  Future<void> _fetchNextPage({required bool isRefresh}) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('companies')
          .doc(companyId)
          .collection('events');

      // Setup Query constraints
      if (state.filters.dates != null) {
        final start = Timestamp.fromDate(state.filters.dates!.start);
        final end = Timestamp.fromDate(state.filters.dates!.end);

        query = query
            .where('end', isGreaterThanOrEqualTo: start)
            .where('end', isLessThanOrEqualTo: end)
            .orderBy('end');
      } else {
        query = query.orderBy(FieldPath.documentId);
      }

      // Handle Pagination logic
      if (!state.filters.isMonthly) {
        query = query.limit(pageSize);
        if (state.lastDocument != null && !isRefresh) {
          query = query.startAfterDocument(state.lastDocument!);
        }
      }

      final snapshot = await query.get();
      final documents = snapshot.docs;

      if (documents.isEmpty) {
        state = state.copyWith(isLoading: false, hasMore: false);
        return;
      }

      // Fetch full event data from the main collection
      final eventIds = documents.map((doc) => doc.id).toList();
      final fetchedEvents = await _fetchEventsByGroupedIds(eventIds);

      // Apply logic-based filters (Past/Current/Upcoming) on client
      final filteredEvents = _applyStatusFilters(
        fetchedEvents,
        state.filters.status,
      );

      final nextEvents = isRefresh 
          ? filteredEvents 
          : [...state.events, ...filteredEvents];

      state = state.copyWith(
        isLoading: false,
        events: nextEvents,
        lastDocument: documents.last,
        hasMore: !state.filters.isMonthly && documents.length == pageSize,
      );

      // If the current batch of IDs didn't yield any visible results due to filters,
      // but there are more documents on the server, fetch the next page immediately.
      if (filteredEvents.isEmpty && state.hasMore) {
        await _fetchNextPage(isRefresh: false);
      }
    } catch (error, stackTrace) {
      debugPrint('MyEventsNotifier error: $error\n$stackTrace');
      state = state.copyWith(isLoading: false, error: error, hasMore: false);
    }
  }

  Future<List<Event>> _fetchEventsByGroupedIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    final snapshot = await _firestore
        .collection('events')
        .where(FieldPath.documentId, whereIn: ids)
        .get();

    final events = snapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] = doc.id;
      return Event.fromJson(data);
    }).toList();

    // Re-sort to maintain the order established by the company-subcollection query
    events.sort((a, b) => ids.indexOf(a.id).compareTo(ids.indexOf(b.id)));
    return events;
  }

  List<Event> _applyStatusFilters(
    List<Event> events,
    Set<EventStatusFilter> activeFilters,
  ) {
    if (activeFilters.isEmpty) return events;

    final now = DateTime.now();

    return events.where((event) {
      // Logic assumes 'isCanceled' is a property of your Event model
      if (activeFilters.contains(EventStatusFilter.canceled) && event.isCanceled) {
        return true;
      }

      if (event.isCanceled) return false;

      final start = event.dates.start;
      final end = event.dates.end;

      if (activeFilters.contains(EventStatusFilter.past) && end.isBefore(now)) {
        return true;
      }
      if (activeFilters.contains(EventStatusFilter.current) && 
          start.isBefore(now) && end.isAfter(now)) {
        return true;
      }
      if (activeFilters.contains(EventStatusFilter.upcoming) && start.isAfter(now)) {
        return true;
      }

      return false;
    }).toList();
  }
}

final companyEventsProvider =
    NotifierProvider.family<MyEventsNotifier, MyEventsState, String>(
  (companyId) => MyEventsNotifier(companyId),
);