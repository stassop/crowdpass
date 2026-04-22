import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/models/event.dart';

import 'package:crowdpass/providers/company_provider.dart';
import 'package:crowdpass/providers/company_events_provider.dart';

import 'package:crowdpass/widgets/refreshable_list.dart';

class CompanyEventsScreen extends ConsumerStatefulWidget {
  const CompanyEventsScreen({super.key});

  @override
  ConsumerState<CompanyEventsScreen> createState() => _CompanyEventsScreenState();
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
    // IMPORTANT: We expressly pass null to companyProvider to get current user's company (or null).
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
            title: Text('My Events'),
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
    // companyEventsProvider is now a family that requires companyId
    final state = ref.watch(companyEventsProvider(companyId));
    final notifier = ref.read(companyEventsProvider(companyId).notifier);

    // Use the pre-split lists from state (no local time filtering needed)
    final List<Event> filteredEvents = switch (eventType) {
      EventTypeFilter.past => state.pastEvents,
      EventTypeFilter.current => state.currentEvents,
      EventTypeFilter.upcoming => state.upcomingEvents,
      EventTypeFilter.canceled => state.canceledEvents,
    };

    // Hook up pagination/refresh to the correct "bucket"
    final bool isLoading = switch (eventType) {
      EventTypeFilter.past => state.isLoadingPast,
      EventTypeFilter.current => state.isLoadingCurrent,
      EventTypeFilter.upcoming => state.isLoadingUpcoming,
      EventTypeFilter.canceled => false, // canceled is derived while fetching
    };

    final bool hasMore = switch (eventType) {
      EventTypeFilter.past => state.hasMorePast,
      EventTypeFilter.current => state.hasMoreCurrent,
      EventTypeFilter.upcoming => state.hasMoreUpcoming,
      EventTypeFilter.canceled => false, // no pagination for canceled bucket here
    };

    Future<void> onRefresh() async {
      // Refresh everything so all tabs stay consistent
      await notifier.refreshAllEvents(clearIds: true);
    }

    Future<void> onLoadMore() async {
      switch (eventType) {
        case EventTypeFilter.past:
          await notifier.fetchPastEvents();
          break;
        case EventTypeFilter.current:
          await notifier.fetchCurrentEvents();
          break;
        case EventTypeFilter.upcoming:
          await notifier.fetchUpcomingEvents();
          break;
        case EventTypeFilter.canceled:
          // No loadMore for canceled bucket (unless you want to implement it separately)
          break;
      }
    }

    return RefreshableList<Event>(
      items: filteredEvents,
      hasMore: hasMore,
      isLoading: isLoading,
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