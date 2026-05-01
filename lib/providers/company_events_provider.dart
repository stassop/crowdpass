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
  final DateTimeRange? dateRange;

  /// Now truly controls query sort by event start date.
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
      // - startAt: Timestamp (event start date)
      //
      // Optionally you can also keep createdAt, endAt, etc. but startAt is what we sort on.
      Query<Map<String, dynamic>> query = _companyEventsRefs
          .orderBy(
            'startAt',
            descending: state.filters.sortBy == EventSortBy.latest,
          )
          .limit(pageSize);

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
      final eventIds = docs.map((d) => d.id).toList();
      final fetched = await _fetchEventsByIdsPreserveOrder(eventIds);

      final List<Event> nextEvents;
      if (replace) {
        nextEvents = fetched;
      } else {
        final existing = state.events.map((e) => e.id).toSet();
        nextEvents = <Event>[
          ...state.events,
          ...fetched.where((e) => !existing.contains(e.id)),
        ];
      }

      state = state.copyWith(
        events: nextEvents,
        hasMore: docs.length == pageSize,
        lastDoc: docs.last,
      );
    } catch (e, st) {
      debugPrint('CompanyEventsNotifier.loadMore error: $e\n$st');
      state = state.copyWith(error: e, hasMore: false);
    }
  }

  void toggleStatusFilter(EventStatusFilter filter) {
    final next = Set<EventStatusFilter>.from(state.filters.status);
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

  Future<List<Event>> _fetchEventsByIdsPreserveOrder(List<String> eventIds) async {
    if (eventIds.isEmpty) return const [];

    final List<Event> all = [];

    // Firestore whereIn limit is 10.
    for (var i = 0; i < eventIds.length; i += 10) {
      final sub = eventIds.skip(i).take(10).toList();
      if (sub.isEmpty) continue;

      final snap = await _events.where(FieldPath.documentId, whereIn: sub).get();

      final events = snap.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return Event.fromJson(data);
      }).toList();

      // preserve order within the sub-batch
      events.sort((a, b) => sub.indexOf(a.id).compareTo(sub.indexOf(b.id)));
      all.addAll(events);
    }

    // preserve order across chunks
    all.sort((a, b) => eventIds.indexOf(a.id).compareTo(eventIds.indexOf(b.id)));
    return all;
  }
}

final companyEventsProvider =
    NotifierProvider.family<CompanyEventsNotifier, CompanyEventsState, String>(
  (companyId) => CompanyEventsNotifier(companyId),
);