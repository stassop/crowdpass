import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' show Distance, LatLng, LengthUnit;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:crowdpass/models/event.dart';
import 'package:crowdpass/models/location.dart';

enum SearchEventsSortBy { distance, date, price }

class SearchEventsFilters {
  final double? distance;
  final LengthUnit distanceUnit;
  final Location? location;
  final Set<EventType>? eventType; // Changed from EventType? to Set<EventType>?
  final DateTimeRange? dates;
  final bool? isFree;
  final bool? doorTicketsAvailable;
  final SearchEventsSortBy sortBy;

  const SearchEventsFilters({
    this.distance,
    this.distanceUnit = LengthUnit.Kilometer,
    this.location,
    this.eventType, // Changed
    this.dates,
    this.isFree,
    this.doorTicketsAvailable,
    this.sortBy = SearchEventsSortBy.date,
  });

  SearchEventsFilters copyWith({
    double? distance,
    LengthUnit? distanceUnit,
    Location? location,
    Set<EventType>? eventType, // Changed
    DateTimeRange? dates,
    bool? isFree,
    bool? doorTicketsAvailable,
    SearchEventsSortBy? sortBy,
  }) {
    return SearchEventsFilters(
      distance: distance ?? this.distance,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      location: location ?? this.location,
      eventType: eventType ?? this.eventType, // Changed
      dates: dates ?? this.dates,
      isFree: isFree ?? this.isFree,
      doorTicketsAvailable: doorTicketsAvailable ?? this.doorTicketsAvailable,
      sortBy: sortBy ?? this.sortBy,
    );
  }
}

class SearchEventsState {
  final SearchEventsFilters filters;
  final List<Event> events;
  final bool hasMore;
  final bool isLoading;
  final Object? error;

  const SearchEventsState({
    this.filters = const SearchEventsFilters(),
    this.events = const [],
    this.hasMore = true,
    this.isLoading = false,
    this.error,
  });

  SearchEventsState copyWith({
    SearchEventsFilters? filters,
    List<Event>? events,
    bool? hasMore,
    bool? isLoading,
    Object? error,
  }) {
    return SearchEventsState(
      filters: filters ?? this.filters,
      events: events ?? this.events,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class SearchEventsNotifier extends Notifier<SearchEventsState> {
  static const int pageSize = 20;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  SearchEventsState build() {
    Future.microtask(refresh);
    return const SearchEventsState();
  }

  Future<void> refresh() async {
    state = state.copyWith(
      events: [],
      hasMore: true,
      isLoading: true,
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
      Query<Map<String, dynamic>> query = _firestore.collection('events');

      // Apply filters
      final filters = state.filters;

      if (filters.eventType != null && filters.eventType!.isNotEmpty) {
        final types = filters.eventType!.map((e) => e.toString()).toList();
        query = query.where('type', whereIn: types);
      }
      if (filters.isFree != null) {
        query = query.where('isFree', isEqualTo: filters.isFree);
      }
      if (filters.doorTicketsAvailable != null) {
        query = query.where(
          'doorTicketsAvailable',
          isEqualTo: filters.doorTicketsAvailable,
        );
      }
      if (filters.dates != null) {
        // Overlap: event.end >= range.start && event.start <= range.end
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

      // Sorting
      switch (state.filters.sortBy) {
        case SearchEventsSortBy.date:
          query = query.orderBy('dates.start', descending: false);
          break;
        case SearchEventsSortBy.price:
          query = query.orderBy('ticketPrice.amount', descending: false);
          break;
        case SearchEventsSortBy.distance:
          // No Firestore-side sort, will sort client-side after geo filtering
          break;
      }

      // Pagination
      if (!replace && state.events.isNotEmpty) {
        final lastEvent = state.events.last;
        switch (state.filters.sortBy) {
          case SearchEventsSortBy.date:
            query = query.startAfter([lastEvent.dates.start.toIso8601String()]);
            break;
          case SearchEventsSortBy.price:
            query = query.startAfter([lastEvent.ticketPrice?.amount ?? 0]);
            break;
          case SearchEventsSortBy.distance:
            // No Firestore-side sort, so no startAfter
            break;
        }
      }

      query = query.limit(pageSize);

      final snapshot = await query.get();
      final docs = snapshot.docs;

      List<Event> fetched = docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return Event.fromJson(data);
      }).toList();

      // Geo filtering (client-side, after Firestore query)
      if (filters.distance != null && filters.location?.latLng != null) {
        final distanceCalc = Distance();
        final double maxDistanceMeters = distanceCalc.as(
          filters.distanceUnit,
          filters.location!.latLng,
          filters.location!.latLng,
        );
        final LatLng center = filters.location!.latLng;
        fetched = fetched.where((event) {
          final LatLng? eventLatLng = event.location.latLng;
          if (eventLatLng == null) return false;
          return Distance().as(LengthUnit.Meter, center, eventLatLng) <=
              maxDistanceMeters;
        }).toList();
      }

      // Location-based filtering using isWithinDistance
      if (filters.location != null && filters.distance != null) {
        final distanceCalc = Distance();
        final double maxDistanceMeters = distanceCalc.as(
          filters.distanceUnit,
          filters.location!.latLng,
          filters.location!.latLng,
        );
        final Location filterLocation = filters.location!;
        fetched = fetched.where((event) {
          // isWithinDistance expects a double for the distance in meters
          return event.location.isWithinDistance(
            filterLocation,
            maxDistanceMeters,
          );
        }).toList();
      }

      // Client-side sort for distance if needed
      if (state.filters.sortBy == SearchEventsSortBy.distance &&
          state.filters.location?.latLng != null) {
        final LatLng center = state.filters.location!.latLng;
        fetched.sort((a, b) {
          final aDist = Distance().distance(a.location.latLng, center);
          final bDist = Distance().distance(b.location.latLng, center);
          return aDist.compareTo(bDist);
        });
      }

      final List<Event> nextEvents = replace
          ? fetched
          : [...state.events, ...fetched];

      state = state.copyWith(
        events: nextEvents,
        hasMore: fetched.length == pageSize,
      );
    } catch (e) {
      state = state.copyWith(error: e, hasMore: false);
    }
  }

  void setFilters(SearchEventsFilters filters) {
    state = state.copyWith(filters: filters);
    Future.microtask(refresh);
  }

  void clearFilters() {
    setFilters(const SearchEventsFilters());
  }
}

final searchEventsProvider =
    NotifierProvider<SearchEventsNotifier, SearchEventsState>(
      SearchEventsNotifier.new,
    );
