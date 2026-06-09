import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/models/event.dart';

/// Filters for company events (date range only)
class CompanyEventsFilters {
  final DateTimeRange? dates;

  const CompanyEventsFilters({
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
  final DateTime? earliestEventDate; // Earliest company event across all time
  final DateTime? latestEventDate; // Latest company event across all time
  final bool isLoading;
  final bool hasMore;
  final Object? error;

  const CompanyEventsState({
    this.events = const [],
    this.filters = const CompanyEventsFilters(),
    this.earliestEventDate,
    this.latestEventDate,
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  CompanyEventsState copyWith({
    List<Event>? events,
    CompanyEventsFilters? filters,
    DateTime? earliestEventDate,
    DateTime? latestEventDate,
    bool? isLoading,
    bool? hasMore,
    Object? error,
  }) {
    return CompanyEventsState(
      events: events ?? this.events,
      filters: filters ?? this.filters,
      earliestEventDate: earliestEventDate ?? this.earliestEventDate,
      latestEventDate: latestEventDate ?? this.latestEventDate,
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

  static const int pageSize = 10;

  @override
  CompanyEventsState build() {
    Future.microtask(() {
      final now = DateTime.now();
      final oneMonthLater = now.add(const Duration(days: 30));
      final defaultRange = DateTimeRange(start: now, end: oneMonthLater);

      final defaultFilters = CompanyEventsFilters(
        dates: defaultRange,
      );

      setFilters(defaultFilters);
    });

    return const CompanyEventsState();
  }

  /// Update filters and refresh events
  void setFilters(CompanyEventsFilters newFilters) {
    if (state.filters == newFilters) return;
    state = state.copyWith(filters: newFilters);
    Future.microtask(refresh);
  }

  /// Clear all filters and refresh with defaults
  void resetFilters() {
    final latest = state.latestEventDate;
    final defaultEnd = latest ?? DateTime.now();
    final defaultStart = defaultEnd.subtract(const Duration(days: 30));
    final defaultRange = DateTimeRange(start: defaultStart, end: defaultEnd);

    final defaultFilters = CompanyEventsFilters(
      dates: defaultRange,
    );

    setFilters(defaultFilters);
  }

  /// Refresh: Clear all events and reload from the beginning
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

  /// Load more: Append next page of events
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true, error: null);
    await _loadMoreInternal(replace: false);
    state = state.copyWith(isLoading: false);
  }

  Future<void> _loadMoreInternal({required bool replace}) async {
    try {
      DateTime? earliest = state.earliestEventDate;
      DateTime? latest = state.latestEventDate;

      if (replace) {
        earliest = await _getEarliestEventDate();
        latest = await _getLatestEventDate();
        state = state.copyWith(
          earliestEventDate: earliest,
          latestEventDate: latest,
        );
        resetFilters();
      }

      final filters = state.filters;

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
      );
    } catch (error, stackTrace) {
      debugPrint('CompanyEventsNotifier error: $error\n$stackTrace');
      state = state.copyWith(error: error, hasMore: false);
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