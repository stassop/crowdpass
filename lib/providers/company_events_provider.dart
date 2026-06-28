import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/models/event.dart';

/// Filters for company events (date range only)
class CompanyEventsFilters {
  final DateTimeRange? dates;

  CompanyEventsFilters({
    this.dates,
  });

  CompanyEventsFilters copyWith({
    DateTimeRange? dates,
  }) {
    return CompanyEventsFilters(
      dates: dates ?? this.dates,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is CompanyEventsFilters && other.dates == dates);
  }

  @override
  int get hashCode => Object.hashAll([dates]);
}

/// State for company events with pagination and error handling
class CompanyEventsState {
  final List<Event> events;
  final CompanyEventsFilters filters;
  final bool isLoading;
  final bool hasMore;
  final Object? error;

  CompanyEventsState({
    this.events = const [],
    CompanyEventsFilters? filters,
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  }) : filters = filters ?? CompanyEventsFilters();

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
    return CompanyEventsState();
  }

  /// Update filters and refresh events
  void setFilters(CompanyEventsFilters newFilters) {
    if (state.filters == newFilters) return;
    state = state.copyWith(filters: newFilters);
    Future.microtask(refresh);
  }

  /// Clear all filters and refresh with defaults
  void resetFilters() {
    state = state.copyWith(filters: CompanyEventsFilters());
    Future.microtask(refresh);
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
        isLoading: true,
        hasMore: true,
        error: null,
      );
    } else {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      var filters = state.filters;

      if (replace) {
        final earliest = await _getEarliestEventDate();
        final latest = await _getLatestEventDate();

        if (earliest != null && latest != null) {
          filters = filters.copyWith(
            dates: DateTimeRange(start: earliest, end: latest),
          );
        }

        state = state.copyWith(filters: filters);
      }

      Query<Map<String, dynamic>> query = _firestore
          .collection('events')
          .where('companyId', isEqualTo: companyId);

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

      final fetchedEvents = docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return Event.fromJson(data);
      }).toList();

      final nextEvents = replace
          ? fetchedEvents
          : [...state.events, ...fetchedEvents];

      state = state.copyWith(
        events: nextEvents,
        hasMore: docs.length == pageSize,
        isLoading: false,
        error: null,
      );
    } catch (error, stackTrace) {
      debugPrint('CompanyEventsNotifier error: $error\n$stackTrace');
      state = state.copyWith(
        isLoading: false,
        hasMore: false,
        error: error,
      );
    }
  }

  /// Fetch the earliest event date for this company
  Future<DateTime?> _getEarliestEventDate() async {
    try {
      final snapshot = await _firestore
          .collection('events')
          .where('companyId', isEqualTo: companyId)
          .orderBy('dates.start', descending: false)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final data = snapshot.docs.first.data();
      final startDateStr = data['dates']['start'] as String?;
      if (startDateStr == null) return null;

      return DateTime.tryParse(startDateStr);
    } catch (error, stackTrace) {
      debugPrint('Error fetching earliest company event date: $error\n$stackTrace');
      return null;
    }
  }

  /// Fetch the latest event date for this company
  Future<DateTime?> _getLatestEventDate() async {
    try {
      final snapshot = await _firestore
          .collection('events')
          .where('companyId', isEqualTo: companyId)
          .orderBy('dates.start', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final data = snapshot.docs.first.data();
      final startDateStr = data['dates']['start'] as String?;
      if (startDateStr == null) return null;

      return DateTime.tryParse(startDateStr);
    } catch (error, stackTrace) {
      debugPrint('Error fetching latest company event date: $error\n$stackTrace');
      return null;
    }
  }
}

final companyEventsProvider =
    NotifierProvider.family<CompanyEventsNotifier, CompanyEventsState, String>(
  (companyId) => CompanyEventsNotifier(companyId),
);