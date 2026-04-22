import 'dart:async';

import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crowdpass/models/event.dart';

import 'package:crowdpass/providers/auth_provider.dart'; // <-- Import authProvider

class MyEventsState {
  final List<Event> currentEvents;
  final List<Event> upcomingEvents;
  final List<Event> pastEvents;
  final List<Event> canceledEvents;
  final bool isLoadingCurrent;
  final bool isLoadingUpcoming;
  final bool isLoadingPast;
  final bool hasMoreCurrent;
  final bool hasMoreUpcoming;
  final bool hasMorePast;
  final Object? error;

  MyEventsState({
    this.currentEvents = const [],
    this.upcomingEvents = const [],
    this.pastEvents = const [],
    this.canceledEvents = const [],
    this.isLoadingCurrent = false,
    this.isLoadingUpcoming = false,
    this.isLoadingPast = false,
    this.hasMoreCurrent = true,
    this.hasMoreUpcoming = true,
    this.hasMorePast = true,
    this.error,
  });

  MyEventsState copyWith({
    List<Event>? currentEvents,
    List<Event>? upcomingEvents,
    List<Event>? pastEvents,
    List<Event>? canceledEvents,
    bool? isLoadingCurrent,
    bool? isLoadingUpcoming,
    bool? isLoadingPast,
    bool? hasMoreCurrent,
    bool? hasMoreUpcoming,
    bool? hasMorePast,
    Object? error,
  }) {
    return MyEventsState(
      currentEvents: currentEvents ?? this.currentEvents,
      upcomingEvents: upcomingEvents ?? this.upcomingEvents,
      pastEvents: pastEvents ?? this.pastEvents,
      canceledEvents: canceledEvents ?? this.canceledEvents,
      isLoadingCurrent: isLoadingCurrent ?? this.isLoadingCurrent,
      isLoadingUpcoming: isLoadingUpcoming ?? this.isLoadingUpcoming,
      isLoadingPast: isLoadingPast ?? this.isLoadingPast,
      hasMoreCurrent: hasMoreCurrent ?? this.hasMoreCurrent,
      hasMoreUpcoming: hasMoreUpcoming ?? this.hasMoreUpcoming,
      hasMorePast: hasMorePast ?? this.hasMorePast,
      error: error,
    );
  }
}

class MyEventsNotifier extends Notifier<MyEventsState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const int pageSize = 20;

  // Cached lists for event IDs by category
  List<String> _currentEventIds = [];
  List<String> _upcomingEventIds = [];
  List<String> _pastEventIds = [];
  List<String> _canceledEventIds = [];
  late final String userId; // Now using userId

  MyEventsNotifier();

  @override
  MyEventsState build() {
    // Get userId from authProvider
    final user = ref.read(authProvider).value;
    if (user == null) {
      // Not authenticated, return empty state
      return MyEventsState();
    }
    userId = user.uid;
    Future.microtask(() => refreshAllEvents(clearIds: true));
    return MyEventsState();
  }

  Future<void> _refreshEventIds() async {
    state = state.copyWith(error: null);

    await Future.wait([
      _fetchSingleIdList('currentEvents', 'createdAt', (ids) => _currentEventIds = ids, fetchCurrentEvents),
      _fetchSingleIdList('upcomingEvents', 'createdAt', (ids) => _upcomingEventIds = ids, fetchUpcomingEvents),
      _fetchSingleIdList('pastEvents', 'createdAt', (ids) => _pastEventIds = ids, fetchPastEvents),
      _fetchSingleIdList('canceledEvents', 'createdAt', (ids) => _canceledEventIds = ids, fetchCanceledEvents),
    ]);
  }

  Future<void> _fetchSingleIdList(
    String collectionName,
    String orderByField,
    void Function(List<String>) onUpdate,
    Future<void> Function({bool refresh}) fetchFunction,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection(collectionName)
          .orderBy(orderByField, descending: true)
          .get();

      final newIds = snapshot.docs.map((doc) => doc.id).toList();
      onUpdate(newIds);

      // Trigger fetching actual event data
      await fetchFunction(refresh: true);
    } catch (error) {
      debugPrint('Error fetching IDs for $collectionName: $error');
      state = state.copyWith(error: error);
    }
  }

  Future<void> refreshAllEvents({bool clearIds = false}) async {
    if (clearIds) {
      _currentEventIds = [];
      _upcomingEventIds = [];
      _pastEventIds = [];
      _canceledEventIds = [];
    }
    await _refreshEventIds();
  }

  Future<void> fetchCurrentEvents({bool refresh = false}) => _fetchEvents(
        eventIds: _currentEventIds,
        currentEvents: state.currentEvents,
        isLoadingFlag: state.isLoadingCurrent,
        isLoadingSetter: (value) => state = state.copyWith(isLoadingCurrent: value),
        hasMoreSetter: (value) => state = state.copyWith(hasMoreCurrent: value),
        onUpdateEvents: (events, canceledEvents) => state = state.copyWith(
          currentEvents: events,
          canceledEvents: refresh ? canceledEvents : [...state.canceledEvents, ...canceledEvents],
        ),
        onClearEvents: () => state = state.copyWith(currentEvents: []),
        refresh: refresh,
      );

  Future<void> fetchUpcomingEvents({bool refresh = false}) => _fetchEvents(
        eventIds: _upcomingEventIds,
        currentEvents: state.upcomingEvents,
        isLoadingFlag: state.isLoadingUpcoming,
        isLoadingSetter: (value) => state = state.copyWith(isLoadingUpcoming: value),
        hasMoreSetter: (value) => state = state.copyWith(hasMoreUpcoming: value),
        onUpdateEvents: (events, canceledEvents) => state = state.copyWith(
          upcomingEvents: events,
          canceledEvents: refresh ? canceledEvents : [...state.canceledEvents, ...canceledEvents],
        ),
        onClearEvents: () => state = state.copyWith(upcomingEvents: []),
        refresh: refresh,
      );

  Future<void> fetchPastEvents({bool refresh = false}) => _fetchEvents(
        eventIds: _pastEventIds,
        currentEvents: state.pastEvents,
        isLoadingFlag: state.isLoadingPast,
        isLoadingSetter: (value) => state = state.copyWith(isLoadingPast: value),
        hasMoreSetter: (value) => state = state.copyWith(hasMorePast: value),
        onUpdateEvents: (events, canceledEvents) => state = state.copyWith(
          pastEvents: events,
          canceledEvents: refresh ? canceledEvents : [...state.canceledEvents, ...canceledEvents],
        ),
        onClearEvents: () => state = state.copyWith(pastEvents: []),
        refresh: refresh,
      );

  Future<void> fetchCanceledEvents({bool refresh = false}) => _fetchEvents(
        eventIds: _canceledEventIds,
        currentEvents: state.canceledEvents,
        isLoadingFlag: false,
        isLoadingSetter: (_) {},
        hasMoreSetter: (_) {},
        onUpdateEvents: (events, _) => state = state.copyWith(canceledEvents: events),
        onClearEvents: () => state = state.copyWith(canceledEvents: []),
        refresh: refresh,
      );

  Future<void> _fetchEvents({
    required List<String> eventIds,
    required List<Event> currentEvents,
    required bool isLoadingFlag,
    required void Function(bool) isLoadingSetter,
    required void Function(bool) hasMoreSetter,
    required void Function(List<Event>, List<Event>) onUpdateEvents,
    required void Function() onClearEvents,
    bool refresh = false,
  }) async {
    if (isLoadingFlag) return;

    isLoadingSetter(true);
    state = state.copyWith(error: null);

    if (refresh) {
      onClearEvents();
      hasMoreSetter(true);
    }

    final startIndex = refresh ? 0 : currentEvents.length;

    if (startIndex >= eventIds.length) {
      hasMoreSetter(false);
      isLoadingSetter(false);
      return;
    }

    final batch = eventIds.skip(startIndex).take(pageSize).toList();

    if (batch.isEmpty) {
      hasMoreSetter(false);
      isLoadingSetter(false);
      return;
    }

    try {
      List<Event> fetchedEvents = [];

      for (var i = 0; i < batch.length; i += 10) {
        final subBatch = batch.skip(i).take(10).toList();
        if (subBatch.isEmpty) continue;

        final snapshot = await _firestore
            .collection('events')
            .where(FieldPath.documentId, whereIn: subBatch)
            .get();

        final events = snapshot.docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id; // Ensure ID is mapped correctly
          return Event.fromJson(data);
        }).toList();

        events.sort((a, b) => batch.indexOf(a.id!).compareTo(batch.indexOf(b.id!)));
        fetchedEvents.addAll(events);
      }

      List<Event> validEvents = [];
      List<Event> newCanceledEvents = [];

      for (var event in fetchedEvents) {
        if (event.isCanceled == true) {
          newCanceledEvents.add(event);
        } else {
          validEvents.add(event);
        }
      }

      final updatedEvents = refresh
          ? validEvents
          : [...currentEvents, ...validEvents];

      onUpdateEvents(updatedEvents, newCanceledEvents);
      hasMoreSetter(fetchedEvents.length == batch.length);
    } catch (e) {
      debugPrint('Error fetching events: $e');
      state = state.copyWith(error: e);
      hasMoreSetter(false);
    } finally {
      isLoadingSetter(false);
    }
  }
}

// Provider definition (no longer family)
final myEventsProvider = NotifierProvider<MyEventsNotifier, MyEventsState>(
  MyEventsNotifier.new,
);