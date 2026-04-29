import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/models/event.dart';

class CompanyEventsState {
  /// Single source list the notifier paginates.
  final List<Event> events;

  /// Derived buckets (computed after each fetch/refresh).
  final List<Event> currentEvents;
  final List<Event> upcomingEvents;
  final List<Event> pastEvents;
  final List<Event> canceledEvents;

  /// One pagination/loading state.
  final bool isLoading;
  final bool hasMore;

  /// Last document for Firestore pagination.
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;

  final Object? error;

  CompanyEventsState({
    this.events = const [],
    this.currentEvents = const [],
    this.upcomingEvents = const [],
    this.pastEvents = const [],
    this.canceledEvents = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.lastDoc,
    this.error,
  });

  CompanyEventsState copyWith({
    List<Event>? events,
    List<Event>? currentEvents,
    List<Event>? upcomingEvents,
    List<Event>? pastEvents,
    List<Event>? canceledEvents,
    bool? isLoading,
    bool? hasMore,
    DocumentSnapshot<Map<String, dynamic>>? lastDoc,
    Object? error,
  }) {
    return CompanyEventsState(
      events: events ?? this.events,
      currentEvents: currentEvents ?? this.currentEvents,
      upcomingEvents: upcomingEvents ?? this.upcomingEvents,
      pastEvents: pastEvents ?? this.pastEvents,
      canceledEvents: canceledEvents ?? this.canceledEvents,
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

  /// Fetch size per page from /companies/{companyId}/events.
  static const int pageSize = 20;

  @override
  CompanyEventsState build() {
    // Kick off initial load.
    Future.microtask(() => refresh());
    return CompanyEventsState();
  }

  CollectionReference<Map<String, dynamic>> get _companyEventsCollection =>
      _firestore.collection('companies').doc(companyId).collection('events');

  /// Public: refreshes and reloads from scratch.
  Future<void> refresh() async {
    await _fetchPage(refresh: true);
  }

  /// Public: loads the next page.
  Future<void> loadMore() async {
    await _fetchPage(refresh: false);
  }

  Future<void> _fetchPage({required bool refresh}) async {
    if (state.isLoading) return;
    if (!refresh && !state.hasMore) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      Query<Map<String, dynamic>> query = _companyEventsCollection
          // Pick an ordering that matches your UX.
          // If you want "most recent first" based on start date:
          .orderBy('dates.start', descending: true)
          .limit(pageSize);

      if (!refresh && state.lastDoc != null) {
        query = query.startAfterDocument(state.lastDoc!);
      }

      final snapshot = await query.get();

      final fetched = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        // Ensure Event.id is present if your model expects it
        data['id'] = doc.id;
        return Event.fromJson(data);
      }).toList();

      final mergedEvents = refresh
          ? fetched
          : [...state.events, ...fetched];

      final buckets = _splitIntoBuckets(mergedEvents, now: DateTime.now());

      state = state.copyWith(
        events: mergedEvents,
        currentEvents: buckets.current,
        upcomingEvents: buckets.upcoming,
        pastEvents: buckets.past,
        canceledEvents: buckets.canceled,
        hasMore: fetched.length == pageSize,
        lastDoc: snapshot.docs.isEmpty ? state.lastDoc : snapshot.docs.last,
      );
    } catch (e, st) {
      debugPrint('Error fetching company events: $e\n$st');
      state = state.copyWith(error: e, hasMore: false);
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  _Buckets _splitIntoBuckets(List<Event> events, {required DateTime now}) {
    final List<Event> canceled = [];
    final List<Event> current = [];
    final List<Event> upcoming = [];
    final List<Event> past = [];

    for (final event in events) {
      // If dates can be null in your model, guard here accordingly.
      final DateTime start = event.dates.start;
      final DateTime end = event.dates.end;

      if (event.isCanceled == true) {
        canceled.add(event);
        continue;
      }

      if (end.isBefore(now)) {
        past.add(event);
      } else if (start.isAfter(now)) {
        upcoming.add(event);
      } else {
        current.add(event);
      }
    }

    // Optional: sort within buckets (since overall list is ordered by start desc)
    // You can tune per bucket:
    //
    // - upcoming: soonest first
    // - current: soonest ending first (or start asc)
    // - past: most recent past first
    upcoming.sort((a, b) => a.dates.start.compareTo(b.dates.start));
    current.sort((a, b) => a.dates.end.compareTo(b.dates.end));
    past.sort((a, b) => b.dates.end.compareTo(a.dates.end));
    // canceled can stay in the merged order, or sort similarly:
    canceled.sort((a, b) => b.dates.start.compareTo(a.dates.start));

    return _Buckets(
      current: current,
      upcoming: upcoming,
      past: past,
      canceled: canceled,
    );
  }
}

class _Buckets {
  final List<Event> current;
  final List<Event> upcoming;
  final List<Event> past;
  final List<Event> canceled;

  _Buckets({
    required this.current,
    required this.upcoming,
    required this.past,
    required this.canceled,
  });
}

final companyEventsProvider = NotifierProvider.family<
    CompanyEventsNotifier, CompanyEventsState, String>(
  (companyId) => CompanyEventsNotifier(companyId),
);