import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    Future.microtask(() {
      ref.read(searchEventsProvider.notifier).refresh();
    });

    ref.listenManual<SearchEventsState>(searchEventsProvider, (previous, next) {
      if (!mounted) return;

      if (next.error != null && previous?.error != next.error) {
        ErrorDialog.show(
          context,
          title: 'Error loading events',
          message: next.error.toString(),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchEventsProvider);
    final notifier = ref.read(searchEventsProvider.notifier);

    final theme = Theme.of(context);

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
                  isEditable: true,
                  decoration: const InputDecoration(
                    labelText: 'Event Type',
                    isDense: true,
                  ),
                  initialValue: state.filters.eventType,
                  onChanged: (eventType) => notifier.setFilters(
                    state.filters.copyWith(eventType: eventType),
                  ),
                ),
                const SizedBox(height: 16),
                EditableLocationField(
                  isEditable: true,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    isDense: true,
                  ),
                  initialValue: state.filters.location,
                  onChanged: (address) => notifier.setFilters(
                    state.filters.copyWith(location: address),
                  ),
                ),
                const SizedBox(height: 16),
                EditableDateRangeField(
                  isEditable: true,
                  decoration: const InputDecoration(
                    labelText: 'Date Range',
                    isDense: true,
                  ),
                  initialValue: state.filters.dates,
                  onChanged: (dateRange) => notifier.setFilters(
                    state.filters.copyWith(dates: dateRange),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Distance', style: theme.textTheme.titleMedium),
                DistanceSlider(
                  min: 0,
                  max: 100,
                  initialValue: state.filters.distance ?? 0,
                  initialUnit: state.filters.distanceUnit,
                  onUnitChanged: (unit) => notifier.setFilters(
                    state.filters.copyWith(distanceUnit: unit),
                  ),
                  onValueChanged: (distance) => notifier.setFilters(
                    state.filters.copyWith(distance: distance),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Sort By', style: theme.textTheme.titleMedium),
                DropdownMenu<SearchEventsSortBy>(
                  key: ValueKey(state.filters.sortBy),
                  expandedInsets: EdgeInsets.zero, 
                  initialSelection: state.filters.sortBy,
                  inputDecorationTheme: const InputDecorationTheme(
                    isDense: true,
                    constraints: BoxConstraints(maxHeight: 48.0),
                    border: OutlineInputBorder(), 
                  ),
                  dropdownMenuEntries: const [
                    DropdownMenuEntry(
                      value: SearchEventsSortBy.date,
                      label: 'Date',
                    ),
                    DropdownMenuEntry(
                      value: SearchEventsSortBy.price,
                      label: 'Price',
                    ),
                    DropdownMenuEntry(
                      value: SearchEventsSortBy.distance,
                      label: 'Distance',
                    ),
                  ],
                  onSelected: (value) {
                    if (value != null) {
                      notifier.setFilters(
                        state.filters.copyWith(sortBy: value),
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset Filters'),
                  onPressed: notifier.resetFilters,
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshableList<Event>(
          onRefresh: notifier.refresh,
          onLoadMore: notifier.loadMore,
          isLoading: state.isLoading,
          hasMore: state.hasMore,
          items: state.events,
          tileBuilder: (context, event, index) => ListTile(
            title: Text(event.title),
            subtitle: Text(event.description),
            trailing: Text(DateTimeService.formatDateTimeRange(event.dates)),
            onTap: () =>
                Navigator.pushNamed(context, '/event/', arguments: event.id),
          ),
        ),
      ),
    );
  }
}