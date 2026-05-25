import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/models/event.dart';

enum EventStatusFilter { past, current, upcoming, canceled }

class CompanyEventsFilters {
  final Set<EventStatusFilter> status;
  final DateTimeRange? dates;

  const CompanyEventsFilters({
    this.status = const {},
    this.dates,
  });

  CompanyEventsFilters copyWith({
    Set<EventStatusFilter>? status,
    DateTimeRange? dates,
  }) {
    return CompanyEventsFilters(
      status: status ?? this.status,
      dates: dates ?? this.dates,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is CompanyEventsFilters &&
            setEquals(other.status, status) &&
            other.dates == dates);
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(
          status.toList()..sort((a, b) => a.index.compareTo(b.index)),
        ),
        dates,
      );
}

class CompanyEventsState {
  final List<Event> events;
  final CompanyEventsFilters filters;
  final bool isLoading;
  final bool hasMore;
  final Object? error;

  const CompanyEventsState({
    this.events = const [],
    this.filters = const CompanyEventsFilters(),
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  CompanyEventsState copyWith({
    List<Event>? events,
    CompanyEventsFilters? filters,
    bool? isLoading,
    bool? hasMore,
    Object? error,
  }) {
    return CompanyEventsState(
      events: events ?? this.events,
      filters: filters ?? this.filters,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

class CompanyEventsNotifier extends Notifier<CompanyEventsState> {
  CompanyEventsNotifier(this.companyId);

  final String companyId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const int pageSize = 30;

  @override
  CompanyEventsState build() {
    Future.microtask(refresh);
    return const CompanyEventsState();
  }

  /// Sets all filters at once and triggers a refresh if they changed.
  void setFilters(CompanyEventsFilters newFilters) {
    if (state.filters == newFilters) return;
    state = state.copyWith(filters: newFilters);
    Future.microtask(refresh);
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

  void clearFilters() {
    setFilters(const CompanyEventsFilters());
  }

  /// Resets the list and starts fetching from the first page.
  Future<void> refresh() async {
    state = state.copyWith(
      events: const [],
      isLoading: true,
      hasMore: true,
      error: null,
    );

    await _loadMoreInternal(replace: true);
    state = state.copyWith(isLoading: false);
  }

  /// Loads the next set of events for pagination.
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true, error: null);
    await _loadMoreInternal(replace: false);
    state = state.copyWith(isLoading: false);
  }

  Future<void> _loadMoreInternal({required bool replace}) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('events')
          .where('companyId', isEqualTo: companyId);

      final filters = state.filters;

      if (filters.dates != null) {
        // Overlap: event end >= selected start && event start <= selected end
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

      query = query.orderBy('dates.start', descending: false);

      if (!replace && state.events.isNotEmpty) {
        final lastEvent = state.events.last;
        query = query.startAfter([lastEvent.dates.start.toIso8601String()]);
      }

      if (!replace) {
        query = query.limit(pageSize);
      }

      final snapshot = await query.get();
      final docs = snapshot.docs;

      var fetchedEvents = docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return Event.fromJson(data);
      }).toList();

      fetchedEvents = _applyStatusFilters(
        fetchedEvents,
        filters.status,
      );

      final nextEvents = replace
          ? fetchedEvents
          : [...state.events, ...fetchedEvents];

      state = state.copyWith(
        events: nextEvents,
        hasMore: docs.length == pageSize,
      );

      // If status filters removed everything from this page, keep paging until
      // we either find visible events or exhaust the result set.
      if (fetchedEvents.isEmpty && docs.length == pageSize) {
        await _loadMoreInternal(replace: false);
      }
    } catch (error, stackTrace) {
      debugPrint('CompanyEventsNotifier error: $error\n$stackTrace');
      state = state.copyWith(error: error, hasMore: false);
    }
  }

  List<Event> _applyStatusFilters(
    List<Event> events,
    Set<EventStatusFilter> activeFilters,
  ) {
    if (activeFilters.isEmpty) return events;

    final now = DateTime.now();

    return events.where((event) {
      if (activeFilters.contains(EventStatusFilter.canceled) &&
          event.isCanceled) {
        return true;
      }

      if (event.isCanceled) return false;

      final start = event.dates.start;
      final end = event.dates.end;

      if (activeFilters.contains(EventStatusFilter.past) &&
          end.isBefore(now)) {
        return true;
      }
      if (activeFilters.contains(EventStatusFilter.current) &&
          start.isBefore(now) &&
          end.isAfter(now)) {
        return true;
      }
      if (activeFilters.contains(EventStatusFilter.upcoming) &&
          start.isAfter(now)) {
        return true;
      }

      return false;
    }).toList();
  }
}

final companyEventsProvider =
    NotifierProvider.family<CompanyEventsNotifier, CompanyEventsState, String>(
  (companyId) => CompanyEventsNotifier(companyId),
);