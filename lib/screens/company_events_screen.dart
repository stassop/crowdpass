import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/providers/company_provider.dart';
import 'package:crowdpass/providers/company_events_provider.dart';

import 'package:crowdpass/widgets/refreshable_list.dart';
import 'package:crowdpass/widgets/error_dialog.dart';
import 'package:crowdpass/widgets/editable_date_range_field.dart';

import 'package:crowdpass/services/date_time_service.dart';

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

        final dates = state.filters.dates;
        final bool anyFilterSelected = dates != null;

        final theme = Theme.of(context);

        if (state.error != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ErrorDialog.show(
              context,
              title: 'Error loading events',
              message: state.error.toString(),
            );
          });
        }

        return Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            title: Text('${company.name} Events'),
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
                  EditableDateRangeField(
                    isEditable: true,
                    initialValue: dates,
                    onChanged: (value) =>
                        notifier.setFilters(state.filters.copyWith(dates: value)),
                  ),
                  const SizedBox(height: 16),
                  if (anyFilterSelected)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset Filters'),
                      onPressed: notifier.resetFilters,
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          body: RefreshableList(
            items: state.events,
            hasMore: state.hasMore,
            isLoading: state.isLoading,
            onRefresh: notifier.refresh,
            onLoadMore: notifier.loadMore,
            tileBuilder: (context, event, index) {
              return ListTile(
                title: Text(event.title),
                subtitle: Text(event.description),
                trailing: Text(DateTimeService.formatDateTimeRange(event.dates)),
                onTap: () =>
                    Navigator.pushNamed(context, '/event/', arguments: event.id),
              );
            },
          ),
        );
      },
    );
  }
}