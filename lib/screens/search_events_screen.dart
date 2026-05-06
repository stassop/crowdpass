import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' show Distance, LatLng, LengthUnit;

import 'package:crowdpass/models/event.dart';

import 'package:crowdpass/providers/search_events_provider.dart';

import 'package:crowdpass/services/date_time_service.dart';

import 'package:crowdpass/widgets/editable_location_field.dart';
import 'package:crowdpass/widgets/editable_date_range_field.dart';
import 'package:crowdpass/widgets/editable_event_type_field.dart';
import 'package:crowdpass/widgets/refreshable_list.dart';
import 'package:crowdpass/widgets/error_dialog.dart';
import 'package:crowdpass/widgets/distance_slider.dart';

class SearchEventsScreen extends ConsumerStatefulWidget {
  const SearchEventsScreen({super.key});

  @override
  ConsumerState<SearchEventsScreen> createState() => _SearchEventsScreenState();
}

class _SearchEventsScreenState extends ConsumerState<SearchEventsScreen> {
  @override
  void initState() {
    super.initState();
    Future(() => ref.read(searchEventsProvider.notifier).refresh());
  }

  // The build method now receives only BuildContext
  @override
  Widget build(BuildContext context) {
    final searchEventsState = ref.watch(searchEventsProvider);
    final searchEventsNotifier = ref.read(searchEventsProvider.notifier);

    final theme = Theme.of(context);

    if (searchEventsState.isLoading && searchEventsState.events.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Search Jobs'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // skip frame and check for errors after build to avoid showing a dialog during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (searchEventsState.error != null) {
        ErrorDialog.show(
          context,
          title: 'Error Loading Events',
          message: searchEventsState.error.toString(),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Jobs'),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.filter_alt),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Filters', style: theme.textTheme.titleLarge),

                const SizedBox(height: 16),

                EditableEventTypeField(
                  isMultiple: true,
                  decoration: const InputDecoration(labelText: 'Event Type', isDense: true),
                  initialValue: searchEventsState.filters.eventType,
                  onChanged: (eventType) => searchEventsNotifier.setFilters(
                    searchEventsState.filters.copyWith(eventType: eventType),
                  ),
                ),

                const SizedBox(height: 16),

                EditableLocationField(
                  decoration: const InputDecoration(labelText: 'Location', isDense: true),
                  initialValue: searchEventsState.filters.location,
                  onChanged: (address) => searchEventsNotifier.setFilters(
                    searchEventsState.filters.copyWith(location: address),
                  ),
                ),

                const SizedBox(height: 16),

                EditableDateRangeField(
                  decoration: const InputDecoration(labelText: 'Date Range', isDense: true),
                  initialValue: searchEventsState.filters.dates,
                  onChanged: (dateRange) => searchEventsNotifier.setFilters(
                    searchEventsState.filters.copyWith(dates: dateRange),
                  ),
                ),

                const SizedBox(height: 16),

                Text('Distance', style: theme.textTheme.titleMedium),

                const SizedBox(height: 8),

                DistanceSlider(
                  min: 0,
                  max: 100,
                  initialDistance: searchEventsState.filters.distance,
                  units: LengthUnit.Kilometer,
                  onChanged: (distance) => searchEventsNotifier.setFilters(
                    searchEventsState.filters.copyWith(distance: distance),
                  ),
                ),

                const SizedBox(height: 16),

                Text('Sort By', style: theme.textTheme.titleMedium),

                const SizedBox(height: 8),

                DropdownButton<SearchEventsSortBy>(
                  value: searchEventsState.filters.sortBy,
                  onChanged: (sortBy) {
                    if (sortBy != null) {
                      searchEventsNotifier.setFilters(
                        searchEventsState.filters.copyWith(sortBy: sortBy),
                      );
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                      value: SearchEventsSortBy.date,
                      child: Text('Soonest Events'),
                    ),
                    DropdownMenuItem(
                      value: SearchEventsSortBy.price,
                      child: Text('Cheapest Events'),
                    ),
                    DropdownMenuItem(
                      value: SearchEventsSortBy.distance,
                      child: Text('Closest Events'),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                ElevatedButton.icon(
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear Filters'),
                  onPressed: searchEventsState.isLoading
                      ? null
                      : () {
                          // The clearFilters() method in the notifier already triggers a fetch.
                          searchEventsNotifier.clearFilters();
                          Navigator.of(context).maybePop();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshableList<Event>(
          onRefresh: () => searchEventsNotifier.refresh(),
          onLoadMore: () => searchEventsNotifier.loadMore(),
          isLoading: searchEventsState.isLoading,
          hasMore: searchEventsState.hasMore,
          items: searchEventsState.events,
          tileBuilder: (context, event, index) => ListTile(
            title: Text(event.title),
            subtitle: Text(event.description),
            trailing: Text(DateTimeService.formatDateTimeRange(event.dates)),
            onTap: () => Navigator.pushNamed(context, '/event/', arguments: event.id),
          ),
        ),
      ),
    );
  }
}