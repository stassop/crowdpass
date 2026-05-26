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

  void setFilters(CompanyEventsFilters newFilters) {
    if (state.filters == newFilters) return;
    state = state.copyWith(filters: newFilters);
    Future.microtask(refresh);
  }

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
      final now = DateTime.now().toIso8601String();

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

      if (filters.status.length == 1) {
        final status = filters.status.first;

        switch (status) {
          case EventStatusFilter.past:
            query = query
                .where('isCanceled', isEqualTo: false)
                .where('dates.end', isLessThan: now)
                .orderBy('dates.end', descending: true);
            break;
          case EventStatusFilter.current:
            query = query
                .where('isCanceled', isEqualTo: false)
                .where('dates.start', isLessThanOrEqualTo: now)
                .where('dates.end', isGreaterThanOrEqualTo: now)
                .orderBy('dates.start', descending: false);
            break;
          case EventStatusFilter.upcoming:
            query = query
                .where('isCanceled', isEqualTo: false)
                .where('dates.start', isGreaterThan: now)
                .orderBy('dates.start', descending: false);
            break;
          case EventStatusFilter.canceled:
            query = query
                .where('isCanceled', isEqualTo: true)
                .orderBy('dates.start', descending: false);
            break;
        }
      } else {
        query = query.orderBy('dates.start', descending: false);
      }

      if (!replace && state.events.isNotEmpty) {
        final lastEvent = state.events.last;

        if (filters.status.length == 1) {
          final status = filters.status.first;

          switch (status) {
            case EventStatusFilter.past:
              query = query.startAfter([lastEvent.dates.end.toIso8601String()]);
              break;
            case EventStatusFilter.current:
            case EventStatusFilter.upcoming:
            case EventStatusFilter.canceled:
              query = query.startAfter([lastEvent.dates.start.toIso8601String()]);
              break;
          }
        } else {
          query = query.startAfter([lastEvent.dates.start.toIso8601String()]);
        }
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
}

final companyEventsProvider =
    NotifierProvider.family<CompanyEventsNotifier, CompanyEventsState, String>(
  (companyId) => CompanyEventsNotifier(companyId),
);