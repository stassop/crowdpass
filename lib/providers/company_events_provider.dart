import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/models/event.dart';

import 'package:crowdpass/providers/company_provider.dart'; // Import CompanyProvider

class CompanyEventsNotifier extends AsyncNotifier<List<Event>> {
  QueryDocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  final int _pageSize = 20;

  late final String? companyId; // Make companyId nullable

  @override
  FutureOr<List<Event>> build() {
    final company = ref.watch(companyProvider(companyId)).value;
    if (company == null) {
      // If no company or company ID is found, return an empty list
      return [];
    }
    companyId = company.id; // Get the company ID
    return _fetchEvents(isRefresh: true);
  }

  Future<List<Event>> _fetchEvents({bool isRefresh = false}) async {
    if (isRefresh) {
      _lastDocument = null;
      _hasMore = true;
    }

    try {
      final now = DateTime.now();
      var query = FirebaseFirestore.instance
          .collection('events')
          .where('companyId', isEqualTo: companyId)
          .orderBy('dates.start')
          .limit(_pageSize);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.length < _pageSize) {
        _hasMore = false;
      }

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }

      final fetchedEvents = snapshot.docs
          .map((doc) => Event.fromJson(doc.data()))
          .toList();

      return fetchedEvents.where((event) {
        if (event.isCanceled == true) return false;

        final eventStart = event.dates.start;
        final eventEnd = event.dates.end;

        return eventEnd.isAfter(now) && eventStart.isBefore(now);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch events: $e');
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore || state.isLoading) return;

    state = const AsyncLoading<List<Event>>().copyWithPrevious(state);

    state = await AsyncValue.guard(() async {
      final newEvents = await _fetchEvents();
      final previousEvents = state.whenData((value) => value).value ?? [];
      return [...previousEvents, ...newEvents];
    });
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchEvents(isRefresh: true));
  }
}

final companyEventsProvider =
    AsyncNotifierProvider.autoDispose<CompanyEventsNotifier, List<Event>>(
  () => CompanyEventsNotifier(),
);