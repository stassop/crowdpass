import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/models/event.dart';
import 'package:crowdpass/providers/auth_provider.dart';
import 'package:crowdpass/providers/user_events_provider.dart';
import 'package:crowdpass/widgets/refreshable_event_list.dart';
import 'package:crowdpass/widgets/error_dialog.dart';
import 'package:crowdpass/widgets/editable_date_range_field.dart';

class UserEventsScreen extends ConsumerStatefulWidget {
  const UserEventsScreen({super.key});

  @override
  ConsumerState<UserEventsScreen> createState() => _UserEventsScreenState();
}

class _UserEventsScreenState extends ConsumerState<UserEventsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.read(userEventsProvider.notifier).refresh();
    });

    ref.listenManual<UserEventsState>(userEventsProvider, (previous, next) {
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

  void _openFilterDrawer() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(authProvider);

    return userAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.maybePop(context)),
          title: const Text('Error'),
        ),
        body: Center(child: Text('Error: $e')),
      ),
      data: (user) {
        if (user == null) {
          return Scaffold(
            appBar: AppBar(
              leading: BackButton(onPressed: () => Navigator.maybePop(context)),
              title: const Text('User Not Found'),
            ),
            body: const Center(
              child: Text('No user is currently logged in.'),
            ),
          );
        }

        final state = ref.watch(userEventsProvider);
        final notifier = ref.read(userEventsProvider.notifier);

        final earliestEventDate = state.earliestEventDate;
        final selectedRoles = state.filters.roles;
        final dates = state.filters.dates;
        final bool anyFilterSelected =
            selectedRoles.isNotEmpty || dates != null;

        final theme = Theme.of(context);

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
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final role in EventRole.values)
                        FilterChip(
                          label: Text(role.label),
                          selected: selectedRoles.contains(role),
                          onSelected: (_) => notifier.toggleRoleFilter(role),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  EditableDateRangeField(
                    isEditable: true,
                    initialValue: dates,
                    firstDate: earliestEventDate,
                    onChanged: (value) {
                      notifier.setFilters(
                        state.filters.copyWith(dates: value),
                      );
                    },
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
          body: RefreshableEventList(
            events: state.events,
            hasMore: state.hasMore,
            isLoading: state.isLoading,
            onRefresh: notifier.refresh,
            onLoadMore: notifier.loadMore,
            itemBuilder: (context, event, index) {
              final userRole = state.eventToRole[event.id];

              return ListTile(
                title: Text(event.title),
                subtitle: Text(event.description),
                trailing: userRole != null ? Text(userRole.label) : null,
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