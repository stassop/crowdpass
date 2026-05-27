import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:crowdpass/models/event.dart';
import 'package:crowdpass/providers/auth_provider.dart';
import 'package:crowdpass/providers/firestore_provider.dart';

final userEventIdsProvider = FutureProvider<List<String>>((ref) async {
  final user = await ref.watch(authProvider.future);
  if (user == null) return const [];

  final firestore = FirebaseFirestore.instance;
  final eventIds = <String>{};

  for (final role in EventRole.values) {
    final snapshot = await firestore
        .collectionGroup(role.name)
        .where('userId', isEqualTo: user.uid)
        .get();

    for (final doc in snapshot.docs) {
      final eventRef = doc.reference.parent.parent;
      if (eventRef != null) {
        eventIds.add(eventRef.id);
      }
    }
  }

  return eventIds.toList();
});

class CalendarFilters {
  final DateTimeRange? dates;

  const CalendarFilters({this.dates});

  CalendarFilters copyWith({DateTimeRange? dates}) {
    return CalendarFilters(dates: dates ?? this.dates);
  }
}

class CalendarState {
  final List<Event> events;
  final CalendarFilters filters;
  final Object? error;
  final bool isLoading;

  const CalendarState({
    this.events = const [],
    this.filters = const CalendarFilters(),
    this.error,
    this.isLoading = false,
  });

  CalendarState copyWith({
    List<Event>? events,
    CalendarFilters? filters,
    Object? error,
    bool clearError = false,
    bool? isLoading,
  }) {
    return CalendarState(
      events: events ?? this.events,
      filters: filters ?? this.filters,
      error: clearError ? null : (error ?? this.error),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class CalendarNotifier extends Notifier<CalendarState> {
  @override
  CalendarState build() {
    return const CalendarState();
  }

  Future<void> setFilters(CalendarFilters filters) async {
    state = state.copyWith(filters: filters);

    final range = filters.dates;
    if (range != null) {
      await fetchEvents(range);
    }
  }

  Future<void> fetchEvents(DateTimeRange range) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final user = await ref.read(authProvider.future);
      if (user == null) {
        state = state.copyWith(
          events: const [],
          isLoading: false,
          clearError: true,
        );
        return;
      }

      final eventIds = await ref.read(userEventIdsProvider.future);
      if (eventIds.isEmpty) {
        state = state.copyWith(
          events: const [],
          isLoading: false,
          clearError: true,
        );
        return;
      }

      final firestore = ref.read(firestoreProvider);
      final start = range.start;
      final endExclusive = range.end;

      final allEvents = <Event>[];

      for (final chunk in _chunk(eventIds, 10)) {
        final snapshot = await firestore
            .collection('events')
            .where(FieldPath.documentId, whereIn: chunk)
            .where('dates.start', isLessThan: Timestamp.fromDate(endExclusive))
            .get();

        final events = snapshot.docs
            .map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return Event.fromJson(data);
            })
            .where((event) => event.dates.end.isAfter(start))
            .toList();

        allEvents.addAll(events);
      }

      allEvents.sort((a, b) => a.dates.start.compareTo(b.dates.start));

      state = state.copyWith(
        events: allEvents,
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        events: const [],
        error: e,
        isLoading: false,
      );
    }
  }

  List<List<String>> _chunk(List<String> values, int size) {
    final chunks = <List<String>>[];

    for (var i = 0; i < values.length; i += size) {
      final end = (i + size < values.length) ? i + size : values.length;
      chunks.add(values.sublist(i, end));
    }

    return chunks;
  }
}

final calendarProvider =
    NotifierProvider<CalendarNotifier, CalendarState>(
  CalendarNotifier.new,
);