import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/models/event.dart';
import 'package:crowdpass/providers/company_provider.dart';
import 'package:crowdpass/providers/company_events_provider.dart';
import 'package:crowdpass/widgets/refreshable_list.dart';

class CompanyEventsScreen extends ConsumerStatefulWidget {
  const CompanyEventsScreen({super.key});

  @override
  ConsumerState<CompanyEventsScreen> createState() =>
      _CompanyEventsScreenState();
}

class _CompanyEventsScreenState extends ConsumerState<CompanyEventsScreen>
    with SingleTickerProviderStateMixin {
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
    final companyAsync = ref.watch(companyProvider(null));

    return companyAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
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
            appBar: AppBar(
              leading: BackButton(onPressed: () => Navigator.maybePop(context)),
              title: const Text('Company Not Found'),
            ),
            body: const Center(
              child: Text('The specified company could not be found.'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('My Events'),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
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
              _EventList(
                  companyId: company.id, eventType: EventTypeFilter.current),
              _EventList(
                  companyId: company.id, eventType: EventTypeFilter.upcoming),
              _EventList(
                  companyId: company.id, eventType: EventTypeFilter.canceled),
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
    final state = ref.watch(companyEventsProvider(companyId));
    final notifier = ref.read(companyEventsProvider(companyId).notifier);

    final List<Event> filteredEvents = switch (eventType) {
      EventTypeFilter.past => state.pastEvents,
      EventTypeFilter.current => state.currentEvents,
      EventTypeFilter.upcoming => state.upcomingEvents,
      EventTypeFilter.canceled => state.canceledEvents,
    };

    Future<void> onRefresh() async {
      await notifier.refresh();
    }

    Future<void> onLoadMore() async {
      // Single pagination stream. If a page contains only upcoming events,
      // past/current lists may not grow until more pages are loaded.
      await notifier.loadMore();
    }

    // Pagination applies to the underlying "events" list, so use the same flags for all tabs.
    // (You can special-case canceled if you want, but this keeps behavior consistent.)
    return RefreshableList<Event>(
      items: filteredEvents,
      hasMore: state.hasMore,
      isLoading: state.isLoading,
      onRefresh: onRefresh,
      onLoadMore: onLoadMore,
      tileBuilder: (context, event, index) => ListTile(
        title: Text(event.title),
        subtitle: Text('${event.dates.start} - ${event.dates.end}'),
        onTap: () =>
            Navigator.pushNamed(context, '/event/', arguments: event.id),
      ),
    );
  }
}