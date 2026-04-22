import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crowdpass/models/event.dart';
import 'package:crowdpass/providers/company_provider.dart';

class CompanyEventsState {
  final List<Event> events;
  final bool isLoading;
  final bool hasMore;
  final Object? error;

  CompanyEventsState({
    this.events = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  CompanyEventsState copyWith({
    List<Event>? events,
    bool? isLoading,
    bool? hasMore,
    Object? error,
  }) {
    return CompanyEventsState(
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

class CompanyEventsNotifier extends Notifier<CompanyEventsState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const int pageSize = 20;
  
  QueryDocumentSnapshot? _lastDocument;
  String? _companyId;

  @override
  CompanyEventsState build() {
    // Watch the company provider to get the current company
    // We use Future.microtask to delay the fetch until after the initial build completes
    Future.microtask(() {
      final company = ref.read(companyProvider(null)).value; // Or however you retrieve the current company ID
      if (company != null) {
        _companyId = company.id;
        refresh();
      } else {
        state = state.copyWith(error: 'Company not found.');
      }
    });

    return CompanyEventsState();
  }

  Future<void> refresh() async {
    _lastDocument = null;
    state = state.copyWith(hasMore: true, error: null);
    await _fetchEvents(isRefresh: true);
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;
    await _fetchEvents(isRefresh: false);
  }

  Future<void> _fetchEvents({bool isRefresh = false}) async {
    if (_companyId == null) return;
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    if (isRefresh) {
      _lastDocument = null;
      state = state.copyWith(events: []);
    }

    try {
      final now = DateTime.now();
      var query = _firestore
          .collection('events')
          .where('companyId', isEqualTo: _companyId)
          .orderBy('dates.start')
          .limit(pageSize);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        state = state.copyWith(hasMore: false, isLoading: false);
        return;
      }

      _lastDocument = snapshot.docs.last;

      final fetchedEvents = snapshot.docs
          .map((doc) {
            final data = doc.data();
            // Assuming Event.fromJson handles the ID if needed, 
            // or you might need to pass doc.id depending on your model.
            return Event.fromJson(data);
          })
          .toList();

      // Filter events based on original business logic
      final validEvents = fetchedEvents.where((event) {
        if (event.isCanceled == true) return false;
        final eventStart = event.dates.start;
        final eventEnd = event.dates.end;
        return eventEnd.isAfter(now) && eventStart.isBefore(now);
      }).toList();

      final updatedEvents = isRefresh
          ? validEvents
          : [...state.events, ...validEvents];

      state = state.copyWith(
        events: updatedEvents,
        hasMore: snapshot.docs.length == pageSize,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('Error fetching company events: $e');
      state = state.copyWith(
        error: e,
        hasMore: false,
        isLoading: false,
      );
    }
  }
}

final companyEventsNotifier =
    NotifierProvider<CompanyEventsNotifier, CompanyEventsState>(
  CompanyEventsNotifier.new,
);