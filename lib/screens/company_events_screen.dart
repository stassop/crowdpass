import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/models/company.dart';
import 'package:crowdpass/models/event.dart';

import 'package:crowdpass/providers/company_provider.dart';
import 'package:crowdpass/providers/event_provider.dart';

import 'package:crowdpass/widgets/refreshable_list.dart';

class CompanyEventsScreen extends ConsumerStatefulWidget {
  const CompanyEventsScreen({super.key});

  @override
  ConsumerState<CompanyEventsScreen> createState() => _CompanyEventsScreenState();
}

class _CompanyEventsScreenState extends ConsumerState<CompanyEventsScreen> with SingleTickerProviderStateMixin {
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
    final companyId = ModalRoute.of(context)?.settings.arguments as String?;
    final companyAsync = ref.watch(companyProvider(companyId));

    return companyAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
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
    return RefreshableList<Event>(
      provider: companyEventsProvider(companyId),
      filter: (event) {
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
      },
      itemBuilder: (context, event) => ListTile(
        title: Text(event.name),
        subtitle: Text('${event.dates.start} - ${event.dates.end}'),
        onTap: () => Navigator.pushNamed(context, '/event/', arguments: event.id),
      ),
    );
}
