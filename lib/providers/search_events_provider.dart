import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' show Distance, LatLng, LengthUnit;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:crowdpass/models/event.dart';
import 'package:crowdpass/models/location.dart';
import 'package:crowdpass/models/distance_unit.dart';

enum SearchEventsSortBy { distance, date, price }

class SearchEventsFilters {
  final double? distance;
  final DistanceUnit distanceUnit;
  final Location? location;
  final Set<EventType>? eventType;
  final DateTimeRange? dates;
  final bool? isFree;
  final bool? doorTicketsAvailable;
  final SearchEventsSortBy sortBy;

  const SearchEventsFilters({
    this.distance,
    this.distanceUnit = DistanceUnit.kilometer,
    this.location,
    this.eventType,
    this.dates,
    this.isFree,
    this.doorTicketsAvailable,
    this.sortBy = SearchEventsSortBy.date,
  });

  SearchEventsFilters copyWith({
    double? distance,
    DistanceUnit? distanceUnit,
    Location? location,
    Set<EventType>? eventType,
    DateTimeRange? dates,
    bool? isFree,
    bool? doorTicketsAvailable,
    SearchEventsSortBy? sortBy,
  }) {
    return SearchEventsFilters(
      distance: distance ?? this.distance,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      location: location ?? this.location,
      eventType: eventType ?? this.eventType,
      dates: dates ?? this.dates,
      isFree: isFree ?? this.isFree,
      doorTicketsAvailable: doorTicketsAvailable ?? this.doorTicketsAvailable,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is SearchEventsFilters &&
            other.distance == distance &&
            other.distanceUnit == distanceUnit &&
            other.location == location &&
            _setEquals(other.eventType, eventType) &&
            other.dates == dates &&
            other.isFree == isFree &&
            other.doorTicketsAvailable == doorTicketsAvailable &&
            other.sortBy == sortBy);
  }

  @override
  int get hashCode => Object.hash(
        distance,
        distanceUnit,
        location,
        eventType == null ? null : Object.hashAllUnordered(eventType!),
        dates,
        isFree,
        doorTicketsAvailable,
        sortBy,
      );

  static bool _setEquals<T>(Set<T>? a, Set<T>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (final value in a) {
      if (!b.contains(value)) return false;
    }
    return true;
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
    await loadMore(replace: true);
  }

  Future<void> loadMore({bool replace = false}) async {
    if (state.isLoading) return;
    if (!replace && !state.hasMore) return;

    if (replace) {
      state = state.copyWith(
        events: const [],
        hasMore: true,
        isLoading: true,
        error: null,
      );
    } else {
      state = state.copyWith(
        isLoading: true,
        error: null,
      );
    }

    try {
      Query<Map<String, dynamic>> query = _firestore.collection('events');

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

      switch (filters.sortBy) {
        case SearchEventsSortBy.date:
          query = query.orderBy('dates.start', descending: false);
          break;
        case SearchEventsSortBy.price:
          query = query.orderBy('ticketPrice.amount', descending: false);
          break;
        case SearchEventsSortBy.distance:
          break;
      }

      if (!replace && state.events.isNotEmpty) {
        final lastEvent = state.events.last;
        switch (filters.sortBy) {
          case SearchEventsSortBy.date:
            query = query.startAfter([lastEvent.dates.start.toIso8601String()]);
            break;
          case SearchEventsSortBy.price:
            query = query.startAfter([lastEvent.ticketPrice?.amount ?? 0]);
            break;
          case SearchEventsSortBy.distance:
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

      if (filters.distance != null && filters.location?.latLng != null) {
        final distanceCalc = Distance();
        final double maxDistanceMeters = distanceCalc.as(
          filters.distanceUnit.lengthUnit,
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

      if (filters.location != null && filters.distance != null) {
        final distanceCalc = Distance();
        final double maxDistanceMeters = distanceCalc.as(
          filters.distanceUnit.lengthUnit,
          filters.location!.latLng,
          filters.location!.latLng,
        );
        final Location filterLocation = filters.location!;

        fetched = fetched.where((event) {
          return event.location.isWithinDistance(
            filterLocation,
            maxDistanceMeters,
          );
        }).toList();
      }

      if (filters.sortBy == SearchEventsSortBy.distance &&
          filters.location?.latLng != null) {
        final LatLng center = filters.location!.latLng;
        fetched.sort((a, b) {
          final aDist = Distance().distance(a.location.latLng, center);
          final bDist = Distance().distance(b.location.latLng, center);
          return aDist.compareTo(bDist);
        });
      }

      final nextEvents = replace ? fetched : [...state.events, ...fetched];

      state = state.copyWith(
        events: nextEvents,
        hasMore: fetched.length == pageSize,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        hasMore: false,
        error: e,
      );
    }
  }

  void setFilters(SearchEventsFilters filters) {
    if (state.filters == filters) return;
    state = state.copyWith(filters: filters);
    Future.microtask(refresh);
  }

  void resetFilters() {
    state = state.copyWith(filters: const SearchEventsFilters());
    Future.microtask(refresh);
  }
}

final searchEventsProvider =
    NotifierProvider<SearchEventsNotifier, SearchEventsState>(
  SearchEventsNotifier.new,
);