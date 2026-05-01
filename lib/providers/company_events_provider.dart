import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/models/event.dart';

enum EventStatusFilter { past, current, upcoming, canceled }
enum EventSortBy { latest, oldest }

class CompanyEventsFilters {
  final Set<EventStatusFilter> status;

  /// Selected date range to filter events by time overlap.
  /// An event matches when: event.end >= range.start && event.start <= range.end
  final DateTimeRange? dateRange;

  /// Controls query sort by event start date.
  final EventSortBy sortBy;

  const CompanyEventsFilters({
    this.status = const {},
    this.dateRange,
    this.sortBy = EventSortBy.latest,
  });

  CompanyEventsFilters copyWith({
    Set<EventStatusFilter>? status,
    DateTimeRange? dateRange,
    EventSortBy? sortBy,
  }) {
    return CompanyEventsFilters(
      status: status ?? this.status,
      dateRange: dateRange ?? this.dateRange,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is CompanyEventsFilters &&
            setEquals(other.status, status) &&
            other.dateRange == dateRange &&
            other.sortBy == sortBy);
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(status.toList()..sort()),
        dateRange,
        sortBy,
      );
}

class CompanyEventsState {
  final List<Event> events;
  final CompanyEventsFilters filters;

  final bool isLoading;
  final bool hasMore;

  /// Cursor for paging company event reference docs.
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;

  final Object? error;

  const CompanyEventsState({
    this.events = const [],
    this.filters = const CompanyEventsFilters(),
    this.isLoading = false,
    this.hasMore = true,
    this.lastDoc,
    this.error,
  });

  CompanyEventsState copyWith({
    List<Event>? events,
    CompanyEventsFilters? filters,
    bool? isLoading,
    bool? hasMore,
    DocumentSnapshot<Map<String, dynamic>>? lastDoc,
    Object? error,
  }) {
    return CompanyEventsState(
      events: events ?? this.events,
      filters: filters ?? this.filters,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      lastDoc: lastDoc ?? this.lastDoc,
      error: error,
    );
  }
}

class CompanyEventsNotifier extends Notifier<CompanyEventsState> {
  CompanyEventsNotifier(this.companyId);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String companyId;

  static const int pageSize = 20;

  CollectionReference<Map<String, dynamic>> get _companyEventsRefs =>
      _firestore.collection('companies').doc(companyId).collection('events');

  CollectionReference<Map<String, dynamic>> get _events =>
      _firestore.collection('events');

  @override
  CompanyEventsState build() {
    Future.microtask(refresh);
    return const CompanyEventsState();
  }

  /// New search: clear results + reset cursor, then fetch first page.
  Future<void> refresh() async {
    if (state.isLoading) return;

    state = state.copyWith(
      events: const [],
      isLoading: true,
      hasMore: true,
      lastDoc: null,
      error: null,
    );

    try {
      await _loadMoreInternal(startAfter: null, replace: true);
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading) return;
    if (!state.hasMore) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      await _loadMoreInternal(
        startAfter: state.lastDoc,
        replace: false,
      );
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _loadMoreInternal({
    required DocumentSnapshot<Map<String, dynamic>>? startAfter,
    required bool replace,
  }) async {
    try {
      // IMPORTANT:
      // This requires companies/{companyId}/events/{eventId} documents to have:
      // - start: Timestamp (event start date)
      // - end: Timestamp (event end date)
      //
      // Date range filter uses OVERLAP logic:
      // event overlaps selected range if:
      //   event.end >= range.start && event.start <= range.end
      //
      // This uses 2 range filters across 2 different fields.
      Query<Map<String, dynamic>> query = _companyEventsRefs;

      final DateTimeRange? dateRange = state.filters.dateRange;
      if (dateRange != null) {
        final Timestamp start = Timestamp.fromDate(dateRange.start);
        final Timestamp end = Timestamp.fromDate(dateRange.end);

        query = query
            .where('end', isGreaterThanOrEqualTo: start)
            .where('start', isLessThanOrEqualTo: end);
      }

      // Sort by event start date.
      query = query.orderBy(
        'start',
        descending: state.filters.sortBy == EventSortBy.latest,
      );

      query = query.limit(pageSize);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      final docs = snapshot.docs;

      if (docs.isEmpty) {
        state = state.copyWith(hasMore: false);
        return;
      }

      // Doc id == eventId
      final List<String> eventIds = docs.map((doc) => doc.id).toList();
      final List<Event> fetchedEvents =
          await _fetchEventsByIdsPreserveOrder(eventIds);

      // Apply status filters client-side (since semantics are often derived from "now"
      // and may not map cleanly to a single Firestore predicate).
      final List<Event> statusFilteredEvents =
          _applyStatusFilters(fetchedEvents, state.filters.status);

      final List<Event> nextEvents;
      if (replace) {
        nextEvents = statusFilteredEvents;
      } else {
        final Set<String> existingIds = state.events.map((event) => event.id).toSet();
        nextEvents = <Event>[
          ...state.events,
          ...statusFilteredEvents.where((event) => !existingIds.contains(event.id)),
        ];
      }

      state = state.copyWith(
        events: nextEvents,
        hasMore: docs.length == pageSize,
        lastDoc: docs.last,
      );
    } catch (error, stackTrace) {
      debugPrint('CompanyEventsNotifier.loadMore error: $error\n$stackTrace');
      state = state.copyWith(error: error, hasMore: false);
    }
  }

  // ---- Filters ----

  void toggleStatusFilter(EventStatusFilter filter) {
    final Set<EventStatusFilter> next = Set<EventStatusFilter>.from(state.filters.status);
    if (next.contains(filter)) {
      next.remove(filter);
    } else {
      next.add(filter);
    }
    _setFiltersAndRestart(state.filters.copyWith(status: next));
  }

  void setDateRange(DateTimeRange? range) {
    _setFiltersAndRestart(state.filters.copyWith(dateRange: range));
  }

  void setSortBy(EventSortBy sortBy) {
    _setFiltersAndRestart(state.filters.copyWith(sortBy: sortBy));
  }

  void clearAllFilters() {
    _setFiltersAndRestart(const CompanyEventsFilters());
  }

  void _setFiltersAndRestart(CompanyEventsFilters next) {
    if (next == state.filters) return;
    state = state.copyWith(filters: next);
    Future.microtask(refresh);
  }

  List<Event> _applyStatusFilters(
    List<Event> events,
    Set<EventStatusFilter> statusFilters,
  ) {
    if (statusFilters.isEmpty) return events;

    final DateTime now = DateTime.now();

    bool matchesAnySelectedStatus(Event event) {
      // If your Event model has an explicit "canceled" flag/status, plug it in here.
      // For now we treat "canceled" as not derivable unless you add it to the model.
      final bool isCanceled = false;

      final DateTimeRange eventDates = event.dates;
      final DateTime start = eventDates.start;
      final DateTime end = eventDates.end;

      bool matches = false;

      if (statusFilters.contains(EventStatusFilter.canceled)) {
        matches = matches || isCanceled;
      }

      if (!isCanceled) {
        if (statusFilters.contains(EventStatusFilter.past)) {
          matches = matches || end.isBefore(now);
        }
        if (statusFilters.contains(EventStatusFilter.current)) {
          matches = matches || (start.isBefore(now) && end.isAfter(now));
        }
        if (statusFilters.contains(EventStatusFilter.upcoming)) {
          matches = matches || start.isAfter(now);
        }
      }

      return matches;
    }

    return events.where(matchesAnySelectedStatus).toList();
  }

  // ---- Fetch referenced events ----

  Future<List<Event>> _fetchEventsByIdsPreserveOrder(List<String> eventIds) async {
    if (eventIds.isEmpty) return const [];

    final List<Event> allEvents = [];

    // Firestore whereIn limit is 10.
    for (int i = 0; i < eventIds.length; i += 10) {
      final List<String> subIds = eventIds.skip(i).take(10).toList();
      if (subIds.isEmpty) continue;

      final snap = await _events.where(FieldPath.documentId, whereIn: subIds).get();

      final List<Event> chunkEvents = snap.docs.map((doc) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return Event.fromJson(data);
      }).toList();

      // preserve order within the sub-batch
      chunkEvents.sort(
        (Event a, Event b) => subIds.indexOf(a.id).compareTo(subIds.indexOf(b.id)),
      );
      allEvents.addAll(chunkEvents);
    }

    // preserve order across chunks
    allEvents.sort(
      (Event a, Event b) =>
          eventIds.indexOf(a.id).compareTo(eventIds.indexOf(b.id)),
    );
    return allEvents;
  }
}

final companyEventsProvider =
    NotifierProvider.family<CompanyEventsNotifier, CompanyEventsState, String>(
  (companyId) => CompanyEventsNotifier(companyId),
);