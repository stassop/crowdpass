import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/models/event.dart';

import 'package:crowdpass/providers/company_provider.dart';
import 'package:crowdpass/providers/company_events_provider.dart'; // Ensure correct import for companyEventsProvider

import 'package:crowdpass/widgets/refreshable_list.dart';

class MyEventsScreen extends ConsumerStatefulWidget {
  const MyEventsScreen({super.key});

  @override
  ConsumerState<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends ConsumerState<MyEventsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(companyProvider(null)); // Pass null to get the current user's company

    return companyAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.maybePop(context)),
          title: const Text('Error'),
        ),
        body: Center(child: Text('Error: $err')),
      ),
      data: (company) {
        if (company == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Company Not Found')),
            body: const Center(child: Text('The specified company could not be found.')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('${company.name} Events'),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Past'),
                Tab(text: 'Current'),
                Tab(text: 'Upcoming'),
                Tab(text: 'Canceled'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _EventList(companyId: company.id, eventType: EventTypeFilter.past),
              _EventList(companyId: company.id, eventType: EventTypeFilter.current),
              _EventList(companyId: company.id, eventType: EventTypeFilter.upcoming),
              _EventList(companyId: company.id, eventType: EventTypeFilter.canceled),
            ],
          ),
        );
      },
    );
  }
}

enum EventTypeFilter { past, current, upcoming, canceled }

class _EventList extends ConsumerWidget {
  final String companyId;
  final EventTypeFilter eventType;

  const _EventList({
    required this.companyId,
    required this.eventType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the new NotifierProvider state
    final state = ref.watch(companyEventsProvider);
    final notifier = ref.read(companyEventsProvider.notifier);

    // Filter events locally based on the tab's type requirement
    final filteredEvents = state.events.where((event) {
      final now = DateTime.now();
      switch (eventType) {
        case EventTypeFilter.past:
          return event.dates.end.isBefore(now) && event.isCanceled != true;
        case EventTypeFilter.current:
          return event.dates.start.isBefore(now) && event.dates.end.isAfter(now) && event.isCanceled != true;
        case EventTypeFilter.upcoming:
          return event.dates.start.isAfter(now) && event.isCanceled != true;
        case EventTypeFilter.canceled:
          return event.isCanceled == true;
      }
    }).toList();

    return RefreshableList<Event>(
      items: filteredEvents,
      hasMore: state.hasMore,
      isLoading: state.isLoading,
      onRefresh: () async => notifier.refresh(),
      onLoadMore: () async => notifier.loadMore(),
      tileBuilder: (context, event, index) => ListTile(
        title: Text(event.title),
        subtitle: Text('${event.dates.start} - ${event.dates.end}'),
        onTap: () => Navigator.pushNamed(context, '/event/', arguments: event.id),
      ),
    );
  }
}