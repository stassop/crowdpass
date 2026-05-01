import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/models/event.dart';

import 'package:crowdpass/providers/company_provider.dart';
import 'package:crowdpass/providers/company_events_provider.dart';

import 'package:crowdpass/widgets/refreshable_list.dart';
import 'package:crowdpass/widgets/error_dialog.dart';

// Assumes this exists in your project as requested.
import 'package:crowdpass/widgets/editable_date_range_field.dart';

class CompanyEventsScreen extends ConsumerStatefulWidget {
  const CompanyEventsScreen({super.key});

  @override
  ConsumerState<CompanyEventsScreen> createState() =>
      _CompanyEventsScreenState();
}

class _CompanyEventsScreenState extends ConsumerState<CompanyEventsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _openFilterDrawer() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(companyProvider(null));

    return companyAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.maybePop(context)),
          title: const Text('Error'),
        ),
        body: Center(child: Text('Error: $e')),
      ),
      data: (company) {
        if (company == null) {
          return Scaffold(
            appBar: AppBar(
              leading: BackButton(onPressed: () => Navigator.maybePop(context)),
              title: const Text('Company Not Found'),
            ),
            body: const Center(
              child: Text('The specified company could not be found.'),
            ),
          );
        }

        final state = ref.watch(companyEventsProvider(company.id));
        final notifier = ref.read(companyEventsProvider(company.id).notifier);

        final selected = state.filters.status;
        final range = state.filters.dateRange;
        final bool anyFilterSelected =
            selected.isNotEmpty || state.filters.dateRange != null;

        final theme = Theme.of(context);

        // Show error dialog if error exists
        if (state.error != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ErrorDialog.show(
              context,
              title: 'Error loading filters',
              message: state.error.toString(),
            );
          });
        }

        return Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            title: const Text('My Events'),
            actions: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _openFilterDrawer,
                tooltip: 'Filters',
              ),
            ],
          ),
          endDrawer: Drawer(
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Filters', style: theme.textTheme.titleLarge),

                  const SizedBox(height: 16),

                  Text('Status', style: theme.textTheme.titleMedium),

                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Past'),
                        selected: selected.contains(EventStatusFilter.past),
                        onSelected: (_) =>
                            notifier.toggleStatusFilter(EventStatusFilter.past),
                      ),
                      FilterChip(
                        label: const Text('Current'),
                        selected: selected.contains(EventStatusFilter.current),
                        onSelected: (_) =>
                            notifier.toggleStatusFilter(EventStatusFilter.current),
                      ),
                      FilterChip(
                        label: const Text('Upcoming'),
                        selected: selected.contains(EventStatusFilter.upcoming),
                        onSelected: (_) =>
                            notifier.toggleStatusFilter(EventStatusFilter.upcoming),
                      ),
                      FilterChip(
                        label: const Text('Canceled'),
                        selected: selected.contains(EventStatusFilter.canceled),
                        onSelected: (_) =>
                            notifier.toggleStatusFilter(EventStatusFilter.canceled),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Text('Date Range', style: theme.textTheme.titleMedium),

                  const SizedBox(height: 8),

                  EditableDateRangeField(
                    isEditable: true,
                    initialValue: range,
                    onChanged: (value) => notifier.setDateRange(value),
                    decoration: const InputDecoration(
                      isDense: true,
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (anyFilterSelected)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear Filters'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: theme.colorScheme.onError,
                      ),
                      onPressed: () {
                        notifier.clearAllFilters();
                      },
                    ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          body: RefreshableList<Event>(
            items: state.visibleEvents,
            hasMore: state.hasMore,
            isLoading: state.isLoading,
            onRefresh: notifier.refresh,
            onLoadMore: notifier.loadMore,
            tileBuilder: (context, event, index) => ListTile(
              title: Text(event.title),
              subtitle: Text('${event.dates.start} - ${event.dates.end}'),
              onTap: () =>
                  Navigator.pushNamed(context, '/event/', arguments: event.id),
            ),
          ),
        );
      },
    );
  }
}
