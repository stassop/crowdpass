import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/models/event.dart';

enum EventStatusFilter { past, current, upcoming, canceled }

class CompanyEventsFilters {
  /// If empty => show all statuses.
  final Set<EventStatusFilter> status;

  /// Optional extra filter by event date overlap with this range.
  /// If null => no date filtering.
  final DateTimeRange? dateRange;

  const CompanyEventsFilters({
    this.status = const {},
    this.dateRange,
  });

  CompanyEventsFilters copyWith({
    Set<EventStatusFilter>? status,
    DateTimeRange? dateRange,
  }) {
    return CompanyEventsFilters(
      status: status ?? this.status,
      dateRange: dateRange,
    );
  }
}

class CompanyEventsState {
  /// All fetched events (paged from membership docs).
  final List<Event> events;

  /// Filtered view (apply drawer filters).
  final List<Event> visibleEvents;

  final CompanyEventsFilters filters;

  final bool isLoading;
  final bool hasMore;

  /// Pagination cursor for membership docs.
  final DocumentSnapshot<Map<String, dynamic>>? lastMembershipDoc;

  final Object? error;

  const CompanyEventsState({
    this.events = const [],
    this.visibleEvents = const [],
    this.filters = const CompanyEventsFilters(),
    this.isLoading = false,
    this.hasMore = true,
    this.lastMembershipDoc,
    this.error,
  });

  CompanyEventsState copyWith({
    List<Event>? events,
    List<Event>? visibleEvents,
    CompanyEventsFilters? filters,
    bool? isLoading,
    bool? hasMore,
    DocumentSnapshot<Map<String, dynamic>>? lastMembershipDoc,
    Object? error,
  }) {
    return CompanyEventsState(
      events: events ?? this.events,
      visibleEvents: visibleEvents ?? this.visibleEvents,
      filters: filters ?? this.filters,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      lastMembershipDoc: lastMembershipDoc ?? this.lastMembershipDoc,
      error: error,
    );
  }
}

class CompanyEventsNotifier extends Notifier<CompanyEventsState> {
  CompanyEventsNotifier(this.companyId);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String companyId;

  static const int pageSize = 20;

  CollectionReference<Map<String, dynamic>> get _membershipCollection =>
      _firestore.collection('companies').doc(companyId).collection('events');

  CollectionReference<Map<String, dynamic>> get _eventsCollection =>
      _firestore.collection('events');

  @override
  CompanyEventsState build() {
    Future.microtask(refresh);
    return const CompanyEventsState();
  }

  Future<void> refresh() async {
    if (state.isLoading) return;

    // Keep filters, reset paging + data.
    state = state.copyWith(
      events: const [],
      visibleEvents: const [],
      isLoading: false,
      hasMore: true,
      lastMembershipDoc: null,
      error: null,
    );

    await loadMore();
  }

  Future<void> loadMore() async {
    if (state.isLoading) return;
    if (!state.hasMore) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      Query<Map<String, dynamic>> query = _membershipCollection
          .orderBy('createdAt', descending: true)
          .limit(pageSize);

      if (state.lastMembershipDoc != null) {
        query = query.startAfterDocument(state.lastMembershipDoc!);
      }

      final snapshot = await query.get();
      final docs = snapshot.docs;

      if (docs.isEmpty) {
        state = state.copyWith(hasMore: false);
        return;
      }

      // Membership doc id == eventId
      final eventIds = docs.map((d) => d.id).toList();

      final fetched = await _fetchEventsByIdsPreserveOrder(eventIds);

      // Merge and de-dupe by id.
      final existing = state.events.map((e) => e.id).toSet();
      final merged = <Event>[
        ...state.events,
        ...fetched.where((e) => !existing.contains(e.id)),
      ];

      state = state.copyWith(
        events: merged,
        hasMore: docs.length == pageSize,
        lastMembershipDoc: docs.last,
      );

      _recomputeVisible();
    } catch (e, st) {
      debugPrint('CompanyEventsNotifier.loadMore error: $e\n$st');
      state = state.copyWith(error: e, hasMore: false);
      _recomputeVisible(); // keep UI consistent (likely shows empty)
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  void toggleStatusFilter(EventStatusFilter filter) {
    final next = Set<EventStatusFilter>.from(state.filters.status);
    if (next.contains(filter)) {
      next.remove(filter);
    } else {
      next.add(filter);
    }

    state = state.copyWith(
      filters: state.filters.copyWith(status: next),
    );
    _recomputeVisible();
  }

  void clearStatusFilters() {
    state = state.copyWith(
      filters: state.filters.copyWith(status: <EventStatusFilter>{}),
    );
    _recomputeVisible();
  }

  void setDateRange(DateTimeRange? range) {
    state = state.copyWith(
      filters: state.filters.copyWith(dateRange: range),
    );
    _recomputeVisible();
  }

  void clearDateRange() => setDateRange(null);

  void clearAllFilters() {
    state = state.copyWith(filters: const CompanyEventsFilters());
    _recomputeVisible();
  }

  Future<List<Event>> _fetchEventsByIdsPreserveOrder(List<String> eventIds) async {
    if (eventIds.isEmpty) return const [];

    final List<Event> all = [];

    for (var i = 0; i < eventIds.length; i += 10) {
      final sub = eventIds.skip(i).take(10).toList();
      if (sub.isEmpty) continue;

      final snap = await _eventsCollection
          .where(FieldPath.documentId, whereIn: sub)
          .get();

      final events = snap.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return Event.fromJson(data);
      }).toList();

      // Preserve membership order within sub-batch
      events.sort((a, b) => sub.indexOf(a.id).compareTo(sub.indexOf(b.id)));
      all.addAll(events);
    }

    // Preserve order across chunks too
    all.sort((a, b) => eventIds.indexOf(a.id).compareTo(eventIds.indexOf(b.id)));
    return all;
  }

  void _recomputeVisible() {
    final now = DateTime.now();

    final filters = state.filters;
    final statusFilters = filters.status;
    final range = filters.dateRange;

    bool matchesStatus(Event e) {
      // If no status filters selected, allow all.
      if (statusFilters.isEmpty) return true;

      final start = e.dates.start;
      final end = e.dates.end;

      final isCanceled = e.isCanceled == true;
      final isPast = !isCanceled && end.isBefore(now);
      final isUpcoming = !isCanceled && start.isAfter(now);
      final isCurrent = !isCanceled && !isPast && !isUpcoming;

      bool ok = false;
      if (statusFilters.contains(EventStatusFilter.canceled)) {
        ok = ok || isCanceled;
      }
      if (statusFilters.contains(EventStatusFilter.past)) {
        ok = ok || isPast;
      }
      if (statusFilters.contains(EventStatusFilter.current)) {
        ok = ok || isCurrent;
      }
      if (statusFilters.contains(EventStatusFilter.upcoming)) {
        ok = ok || isUpcoming;
      }

      return ok;
    }

    bool matchesRange(Event e) {
      if (range == null) return true;

      // "Overlap" logic: keep event if it intersects the selected range.
      // event: [start, end], range: [rs, re]
      final start = e.dates.start;
      final end = e.dates.end;

      return !end.isBefore(range.start) && !start.isAfter(range.end);
    }

    final visible = state.events
        .where((e) => matchesStatus(e) && matchesRange(e))
        .toList(growable: false);

    state = state.copyWith(visibleEvents: visible);
  }
}

final companyEventsProvider =
    NotifierProvider.family<CompanyEventsNotifier, CompanyEventsState, String>(
  (companyId) => CompanyEventsNotifier(companyId),
);